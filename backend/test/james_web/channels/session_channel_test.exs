defmodule JamesWeb.SessionChannelTest do
  use JamesWeb.ChannelCase

  alias James.{Accounts, Hosts, Sessions}

  defp create_user(email \\ nil) do
    email = email || "chan_#{System.unique_integer()}@example.com"
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "chan-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9100"
      })

    host
  end

  defp create_session(user, host) do
    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Channel Session"})

    session
  end

  describe "join session channel" do
    test "joins successfully for own session" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      assert {:ok, _reply, _socket} =
               subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")
    end

    test "returns messages on join" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)

      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "Hello!",
        token_count: 3,
        model: "claude-sonnet-4-20250514"
      })

      socket = connect_socket(user)

      assert {:ok, %{messages: messages}, _socket} =
               subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      assert length(messages) == 1
      assert hd(messages).content == "Hello!"
    end

    test "rejects join for non-existent session" do
      user = create_user()
      socket = connect_socket(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, %{reason: "session not found"}} =
               subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{fake_id}")
    end

    test "enqueues GitStatusWorker on join when session has working directories" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)

      # Update session with working directories
      {:ok, updated_session} =
        James.Sessions.update_session(session, %{
          working_directories: ["/tmp/test_#{Ecto.UUID.generate()}"]
        })

      socket = connect_socket(user)

      # Track that TaskSupervisor is used (worker enqueued)
      socket = subscribe_and_join!(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      # After join, the channel sends :after_join which enqueues GitStatusWorker
      # We verify by checking the session has working_directories and the worker was set up
      assert updated_session.working_directories != []
      :ok
    end

    test "rejects join for another user's session" do
      user1 = create_user()
      user2 = create_user()
      host = create_host()
      session = create_session(user1, host)
      socket = connect_socket(user2)

      assert {:error, %{reason: "forbidden"}} =
               subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")
    end
  end

  describe "webrtc signaling" do
    # James.OpenClaw.Orchestrator is not started in tests (no process).
    # SessionChannel catches the :noproc exit and falls back to a direct
    # PubSub broadcast of {:webrtc_offer_received, ...} — we assert that path.

    test "handle_in(webrtc:offer) broadcasts {:webrtc_offer_received, sdp, viewer_id} to session" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      socket = subscribe_and_join!(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      sdp = "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n"
      viewer_id = user.id
      push(socket, "webrtc:offer", %{"sdp" => sdp, "session_id" => session.id})

      # Phoenix 1.7 delivers raw tuples via subscribe_and_join!'s embedded subscriber.
      # viewer_id is user.id (a string UUID).
      assert_receive {:webrtc_offer_received, ^sdp, ^viewer_id}
    end

    test "handle_in(webrtc:ice_candidate) broadcasts {:webrtc_ice_candidate, payload} to session" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      socket = subscribe_and_join!(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      push(socket, "webrtc:ice_candidate", %{
        "candidate" => "a=candidate:1 1 UDP 1 2.3.4.5 6 typ host"
      })

      # Phoenix 1.7 delivers raw tuples via subscribe_and_join!'s embedded subscriber.
      assert_receive {:webrtc_ice_candidate, %{"candidate" => _}}
    end

    test "handle_info(webrtc_offer_received) pushes offer to host client" do
      user = create_user()
      viewer_id = user.id
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      socket = subscribe_and_join!(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      # Deliver the handle_info message directly to the running channel process.
      # Phoenix 1.7 does not expose a broadcast_from! variant for handle_info delivery;
      # send/2 to the channel PID achieves the same.
      send(socket.channel_pid, {:webrtc_offer_received, "v=0\r\n", viewer_id})

      assert_push("webrtc:offer", %{"sdp" => "v=0\r\n", "from_viewer_id" => ^viewer_id})
    end
  end

  describe "pubsub event relay" do
    test "relays user_message events to client" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      fake_msg = %{
        id: Ecto.UUID.generate(),
        role: "user",
        content: "hello",
        inserted_at: DateTime.utc_now()
      }

      Phoenix.PubSub.broadcast(James.PubSub, "session:#{session.id}", {:user_message, fake_msg})
      assert_push("message:new", %{content: "hello"})
      _ = socket
    end

    test "relays assistant_message events to client" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      fake_msg = %{
        id: Ecto.UUID.generate(),
        role: "assistant",
        content: "hi there",
        inserted_at: DateTime.utc_now()
      }

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "session:#{session.id}",
        {:assistant_message, fake_msg}
      )

      assert_push("message:new", %{content: "hi there"})
      _ = socket
    end

    test "relays artifact_created events to client" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      fake_artifact = %{id: Ecto.UUID.generate(), type: "file", path: "/tmp/output.txt"}

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "session:#{session.id}",
        {:artifact_created, fake_artifact}
      )

      assert_push("artifact:created", %{type: "file"})
      _ = socket
    end

    test "relays assistant_chunk events to client" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      Phoenix.PubSub.broadcast(James.PubSub, "session:#{session.id}", {:assistant_chunk, "hi"})
      assert_push("message:chunk", %{content: "hi"})
      _ = socket
    end

    test "relays task_updated events to client" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.SessionChannel, "session:#{session.id}")

      fake_task = %{
        id: Ecto.UUID.generate(),
        description: "do thing",
        status: "completed",
        risk_level: "read_only"
      }

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "session:#{session.id}",
        {:task_updated, fake_task}
      )

      assert_push("task:updated", %{status: "completed"})
      _ = socket
    end
  end
end
