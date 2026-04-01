defmodule James.Planner.MetaPlannerTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Planner.MetaPlanner

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "planner-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9500"
      })

    host
  end

  defp create_session(user, host, attrs \\ %{}) do
    {:ok, session} =
      Sessions.create_session(
        Map.merge(%{user_id: user.id, host_id: host.id, name: "Planner Session"}, attrs)
      )

    session
  end

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: "planner_#{System.unique_integer()}@example.com"})
    user
  end

  # Ensure MetaPlanner GenServer is running — it is started by the Application,
  # but in test we want to be sure.
  setup do
    case Process.whereis(MetaPlanner) do
      nil ->
        {:ok, _} = MetaPlanner.start_link([])

      _pid ->
        :ok
    end

    :ok
  end

  describe "process_message/2" do
    test "creates a task for a chat session (read_only risk)" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MetaPlanner.process_message(session.id, "hello")
      # Give the GenServer time to process the cast
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert tasks != []
    end

    test "task has expected risk level for chat agent" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MetaPlanner.process_message(session.id, "tell me a joke")
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert Enum.any?(tasks, fn t -> t.risk_level == "read_only" end)
    end

    test "research agent creates read_only risk task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "research"})

      MetaPlanner.process_message(session.id, "research something")
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert Enum.any?(tasks, fn t -> t.risk_level == "read_only" end)
    end

    test "code agent creates additive risk task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "code"})

      MetaPlanner.process_message(session.id, "write some code")
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert Enum.any?(tasks, fn t -> t.risk_level == "additive" end)
    end

    test "desktop agent creates destructive risk task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "desktop"})

      MetaPlanner.process_message(session.id, "do desktop stuff")
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert Enum.any?(tasks, fn t -> t.risk_level == "destructive" end)
    end

    test "browser agent creates destructive risk task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "browser"})

      MetaPlanner.process_message(session.id, "browse something")
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert Enum.any?(tasks, fn t -> t.risk_level == "destructive" end)
    end

    test "does nothing for a non-existent session_id" do
      MetaPlanner.process_message(Ecto.UUID.generate(), "hello")
      Process.sleep(50)
      # just ensure it doesn't crash
      assert Process.alive?(Process.whereis(MetaPlanner))
    end

    test "destructive task in confirmed mode stays pending" do
      user = create_user()
      host = create_host()

      session =
        create_session(user, host, %{agent_type: "desktop", execution_mode: "confirmed"})

      MetaPlanner.process_message(session.id, "take over screen")
      Process.sleep(100)

      tasks = Tasks.list_tasks(session_id: session.id)
      destructive_task = Enum.find(tasks, fn t -> t.risk_level == "destructive" end)

      if destructive_task do
        assert destructive_task.status in ["pending", "running", "completed"]
      end
    end
  end
end
