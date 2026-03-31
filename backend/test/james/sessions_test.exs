defmodule James.SessionsTest do
  use James.DataCase

  alias James.{Accounts, Sessions}

  defp create_user(email \\ "session_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user, attrs \\ %{}) do
    {:ok, session} =
      Sessions.create_session(Map.merge(%{user_id: user.id, name: "Test Session"}, attrs))

    session
  end

  describe "create_session/1" do
    test "creates a session with a user_id" do
      user = create_user()
      assert {:ok, session} = Sessions.create_session(%{user_id: user.id})
      assert session.user_id == user.id
    end

    test "sets default status to active" do
      user = create_user("default_status@example.com")
      {:ok, session} = Sessions.create_session(%{user_id: user.id})
      assert session.status == "active"
    end

    test "sets default agent_type to chat" do
      user = create_user("default_agent@example.com")
      {:ok, session} = Sessions.create_session(%{user_id: user.id})
      assert session.agent_type == "chat"
    end

    test "fails when user_id is missing" do
      assert {:error, changeset} = Sessions.create_session(%{name: "No User"})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid agent_type" do
      user = create_user("bad_agent@example.com")

      assert {:error, changeset} =
               Sessions.create_session(%{user_id: user.id, agent_type: "invalid"})

      assert %{agent_type: [_]} = errors_on(changeset)
    end

    test "rejects invalid status" do
      user = create_user("bad_status@example.com")

      assert {:error, changeset} =
               Sessions.create_session(%{user_id: user.id, status: "unknown"})

      assert %{status: [_]} = errors_on(changeset)
    end
  end

  describe "get_session/1" do
    test "returns session by id" do
      user = create_user("get_sess@example.com")
      session = create_session(user)
      assert found = Sessions.get_session(session.id)
      assert found.id == session.id
    end

    test "returns nil for unknown id" do
      assert Sessions.get_session(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_sessions/2" do
    test "lists sessions for user" do
      user = create_user("list_sess@example.com")
      create_session(user, %{name: "Session A"})
      create_session(user, %{name: "Session B"})
      sessions = Sessions.list_sessions(user.id)
      assert length(sessions) == 2
    end

    test "does not return other users' sessions" do
      user1 = create_user("list_sess_u1@example.com")
      user2 = create_user("list_sess_u2@example.com")
      create_session(user1)
      sessions = Sessions.list_sessions(user2.id)
      assert sessions == []
    end

    test "respects the limit option" do
      user = create_user("list_limit@example.com")
      for i <- 1..5, do: create_session(user, %{name: "S#{i}"})
      sessions = Sessions.list_sessions(user.id, limit: 3)
      assert length(sessions) == 3
    end

    test "excludes archived sessions" do
      user = create_user("list_archived@example.com")
      session = create_session(user)
      Sessions.update_session(session, %{status: "archived"})
      sessions = Sessions.list_sessions(user.id)
      assert sessions == []
    end
  end

  describe "update_session/2" do
    test "updates session name" do
      user = create_user("update_sess@example.com")
      session = create_session(user, %{name: "Old Name"})
      assert {:ok, updated} = Sessions.update_session(session, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "updates session status" do
      user = create_user("update_status@example.com")
      session = create_session(user)
      assert {:ok, updated} = Sessions.update_session(session, %{status: "idle"})
      assert updated.status == "idle"
    end
  end

  describe "delete_session/1" do
    test "removes the session" do
      user = create_user("delete_sess@example.com")
      session = create_session(user)
      {:ok, _} = Sessions.archive_session(session)
      found = Sessions.get_session(session.id)
      assert found.status == "archived"
    end
  end

  describe "create_message/1" do
    test "creates a message in a session" do
      user = create_user("create_msg@example.com")
      session = create_session(user)

      assert {:ok, msg} =
               Sessions.create_message(%{
                 session_id: session.id,
                 role: "user",
                 content: "Hello"
               })

      assert msg.session_id == session.id
      assert msg.role == "user"
      assert msg.content == "Hello"
    end

    test "fails when session_id is missing" do
      assert {:error, changeset} = Sessions.create_message(%{role: "user"})
      assert %{session_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when role is missing" do
      user = create_user("msg_no_role@example.com")
      session = create_session(user)
      assert {:error, changeset} = Sessions.create_message(%{session_id: session.id})
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid role" do
      user = create_user("msg_bad_role@example.com")
      session = create_session(user)

      assert {:error, changeset} =
               Sessions.create_message(%{session_id: session.id, role: "robot"})

      assert %{role: [_]} = errors_on(changeset)
    end
  end

  describe "list_messages/1" do
    test "returns messages for session in insertion order" do
      user = create_user("list_msg@example.com")
      session = create_session(user)
      {:ok, _} = Sessions.create_message(%{session_id: session.id, role: "user", content: "First"})

      {:ok, _} =
        Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Second"})

      messages = Sessions.list_messages(session.id)
      assert length(messages) == 2
      assert hd(messages).content == "First"
    end

    test "returns empty list when no messages" do
      user = create_user("empty_msg@example.com")
      session = create_session(user)
      assert Sessions.list_messages(session.id) == []
    end
  end

  describe "create_checkpoint/1" do
    test "creates a checkpoint for a session" do
      user = create_user("create_cp@example.com")
      session = create_session(user)

      assert {:ok, cp} =
               Sessions.create_checkpoint(%{
                 session_id: session.id,
                 type: "explicit",
                 name: "My Checkpoint"
               })

      assert cp.session_id == session.id
      assert cp.type == "explicit"
      assert cp.name == "My Checkpoint"
    end

    test "fails when session_id is missing" do
      assert {:error, changeset} = Sessions.create_checkpoint(%{type: "implicit"})
      assert %{session_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_checkpoints/1" do
    test "returns checkpoints for session" do
      user = create_user("list_cp@example.com")
      session = create_session(user)
      {:ok, _} = Sessions.create_checkpoint(%{session_id: session.id, type: "implicit"})
      {:ok, _} = Sessions.create_checkpoint(%{session_id: session.id, type: "explicit", name: "X"})
      cps = Sessions.list_checkpoints(session.id)
      assert length(cps) == 2
    end

    test "returns empty list when no checkpoints" do
      user = create_user("no_cp@example.com")
      session = create_session(user)
      assert Sessions.list_checkpoints(session.id) == []
    end
  end

  describe "rewind_to_checkpoint/1" do
    test "restores conversation snapshot and returns {:ok, checkpoint}" do
      user = create_user("rewind@example.com")
      session = create_session(user)

      {:ok, _} =
        Sessions.create_message(%{session_id: session.id, role: "user", content: "Before"})

      {:ok, cp} = Sessions.create_explicit_checkpoint(session.id, "snap")

      {:ok, _} =
        Sessions.create_message(%{session_id: session.id, role: "user", content: "After"})

      assert {:ok, restored_cp} = Sessions.rewind_to_checkpoint(cp.id)
      assert restored_cp.id == cp.id

      messages = Sessions.list_messages(session.id)
      assert length(messages) == 1
      assert hd(messages).content == "Before"
    end

    test "returns {:error, :not_found} for unknown checkpoint id" do
      assert {:error, :not_found} = Sessions.rewind_to_checkpoint(Ecto.UUID.generate())
    end
  end
end
