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
