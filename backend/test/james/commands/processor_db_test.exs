defmodule James.Commands.ProcessorDbTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions}
  alias James.Commands.Processor

  defp create_session(attrs \\ %{}) do
    {:ok, user} = Accounts.create_user(%{email: "pcmd_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "pcmd-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9000"
      })

    {:ok, session} =
      Sessions.create_session(
        Map.merge(%{user_id: user.id, host_id: host.id, name: "Cmd Session"}, attrs)
      )

    session
  end

  describe "/clear" do
    test "deletes all messages in the session" do
      session = create_session()
      Sessions.create_message(%{session_id: session.id, role: "user", content: "hi"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "hello"})

      assert {:command, "Conversation cleared."} = Processor.process("/clear", session.id)
      assert Sessions.list_messages(session.id) == []
    end

    test "is a no-op when the session has no messages" do
      session = create_session()
      assert {:command, "Conversation cleared."} = Processor.process("/clear", session.id)
    end
  end

  describe "/rename" do
    test "renames the session" do
      session = create_session()
      assert {:command, text} = Processor.process("/rename My New Name", session.id)
      assert String.contains?(text, "My New Name")
      assert Sessions.get_session(session.id).name == "My New Name"
    end

    test "returns usage hint when no name given" do
      session = create_session()
      assert {:command, text} = Processor.process("/rename", session.id)
      assert String.contains?(text, "Usage")
    end

    test "returns not-found message for unknown session_id" do
      assert {:command, "Session not found."} =
               Processor.process("/rename Foo", Ecto.UUID.generate())
    end
  end

  describe "/cost" do
    test "returns no-usage message when no token records exist" do
      session = create_session()
      assert {:command, text} = Processor.process("/cost", session.id)
      assert String.contains?(text, "No token usage")
    end
  end

  describe "/status" do
    test "returns session details" do
      session = create_session()
      assert {:command, text} = Processor.process("/status", session.id)
      assert text =~ "Session"
      assert text =~ "Agent"
    end

    test "returns not-found for unknown session" do
      assert {:command, "Session not found."} =
               Processor.process("/status", Ecto.UUID.generate())
    end
  end

  describe "/context" do
    test "returns the message count" do
      session = create_session()
      Sessions.create_message(%{session_id: session.id, role: "user", content: "hi"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "ok"})

      assert {:command, text} = Processor.process("/context", session.id)
      assert text =~ "2 messages"
    end

    test "returns 0 messages for empty session" do
      session = create_session()
      assert {:command, text} = Processor.process("/context", session.id)
      assert text =~ "0 messages"
    end
  end

  describe "/checkpoint" do
    test "creates an implicit checkpoint" do
      session = create_session()
      assert {:command, "Checkpoint created."} = Processor.process("/checkpoint", session.id)
      assert [_] = Sessions.list_checkpoints(session.id)
    end

    test "creates a named checkpoint" do
      session = create_session()
      assert {:command, text} = Processor.process("/checkpoint before-refactor", session.id)
      assert text =~ "before-refactor"
      [cp] = Sessions.list_checkpoints(session.id)
      assert cp.name == "before-refactor"
      assert cp.type == "explicit"
    end
  end

  describe "/rewind" do
    test "rewinds to latest checkpoint" do
      session = create_session()
      Sessions.create_message(%{session_id: session.id, role: "user", content: "first"})
      {:command, _} = Processor.process("/checkpoint v1", session.id)
      Sessions.create_message(%{session_id: session.id, role: "user", content: "after"})

      assert {:command, text} = Processor.process("/rewind", session.id)
      assert text =~ "Rewound"
      assert text =~ "v1"
    end

    test "returns no-checkpoints message when none exist" do
      session = create_session()
      assert {:command, text} = Processor.process("/rewind", session.id)
      assert text =~ "No checkpoints"
    end

    test "returns usage when extra args given" do
      session = create_session()
      assert {:command, text} = Processor.process("/rewind abc", session.id)
      assert text =~ "Usage"
    end
  end
end
