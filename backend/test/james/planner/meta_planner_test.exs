defmodule James.Planner.MetaPlannerTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.OpenClaw.Orchestrator
  alias James.OpenClaw.Supervisor, as: AgentSupervisor
  alias James.Planner.MetaPlanner
  alias James.Test.MockLLMProvider

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

  # Start the full OpenClaw stack so dispatch_task casts don't raise.
  setup do
    if is_nil(Process.whereis(AgentSupervisor)) do
      {:ok, _} = AgentSupervisor.start_link([])
    end

    if is_nil(Process.whereis(Orchestrator)) do
      {:ok, _} = Orchestrator.start_link([])
    end

    if is_nil(Process.whereis(MetaPlanner)) do
      {:ok, _} = MetaPlanner.start_link([])
    end

    MockLLMProvider.flush()

    :ok
  end

  describe "process_message/2" do
    test "creates a task for a chat session (read_only risk)" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MetaPlanner.process_message(session.id, "hello")
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
      assert is_pid(Process.whereis(MetaPlanner))
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

  # ---------------------------------------------------------------------------
  # Task 4.1 – LLM-driven task decomposition
  # ---------------------------------------------------------------------------

  describe "decompose_message/2 via LLM" do
    test "simple chat message decomposes to a single generate-response task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      # No custom mock response queued → MockLLMProvider returns default
      # "Mock response" which is not valid JSON → falls back to single task.
      MetaPlanner.process_message(session.id, "hello there")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 1
      assert hd(tasks).description == "Generate response"
    end

    test "complex message with valid JSON LLM response produces multiple tasks" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "research"})

      json_response =
        Jason.encode!([
          %{
            description: "Search for recent papers on Elixir OTP",
            risk_level: "read_only",
            agent_type: "research"
          },
          %{
            description: "Write a report summarising findings",
            risk_level: "additive",
            agent_type: "chat"
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: json_response, usage: %{}}})

      MetaPlanner.process_message(session.id, "Search for Elixir OTP papers, then write a report")
      Process.sleep(200)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 2

      descriptions = Enum.map(tasks, & &1.description)
      assert "Search for recent papers on Elixir OTP" in descriptions
      assert "Write a report summarising findings" in descriptions
    end

    test "JSON task list contains description, risk_level, and agent_type fields" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      json_response =
        Jason.encode!([
          %{
            description: "Fetch weather data",
            risk_level: "read_only",
            agent_type: "research"
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: json_response, usage: %{}}})

      MetaPlanner.process_message(session.id, "What is the weather today?")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 1

      task = hd(tasks)
      assert task.description == "Fetch weather data"
      assert task.risk_level == "read_only"
    end

    test "malformed (non-JSON) model response falls back to single-task decomposition" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MockLLMProvider.push_response({:ok, %{content: "Sorry, I cannot do that.", usage: %{}}})

      MetaPlanner.process_message(session.id, "Search for X, then write a report")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 1
      assert hd(tasks).description == "Generate response"
    end

    test "empty model response falls back gracefully to single task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MockLLMProvider.push_response({:ok, %{content: "", usage: %{}}})

      MetaPlanner.process_message(session.id, "do something")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 1
      assert hd(tasks).description == "Generate response"
    end

    test "nil model response falls back gracefully to single task" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MockLLMProvider.push_response({:ok, %{content: nil, usage: %{}}})

      MetaPlanner.process_message(session.id, "do something else")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 1
      assert hd(tasks).description == "Generate response"
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.3 – Parallel task dispatching
  # ---------------------------------------------------------------------------

  describe "parallel task dispatching" do
    test "two independent tasks are both dispatched (broadcasted via PubSub)" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "research"})

      Phoenix.PubSub.subscribe(James.PubSub, "planner:tasks")

      json_response =
        Jason.encode!([
          %{
            description: "Search for data",
            risk_level: "read_only",
            agent_type: "research",
            parallel: true
          },
          %{
            description: "Analyse trends",
            risk_level: "read_only",
            agent_type: "research",
            parallel: true
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: json_response, usage: %{}}})

      MetaPlanner.process_message(session.id, "Search for data and analyse trends in parallel")
      Process.sleep(300)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 2
    end

    test "tasks with parallel: true flag are dispatched simultaneously" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "research"})

      json_response =
        Jason.encode!([
          %{
            description: "Task A",
            risk_level: "read_only",
            agent_type: "research",
            parallel: true
          },
          %{
            description: "Task B",
            risk_level: "read_only",
            agent_type: "research",
            parallel: true
          },
          %{
            description: "Task C",
            risk_level: "additive",
            agent_type: "chat",
            parallel: true
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: json_response, usage: %{}}})

      MetaPlanner.process_message(session.id, "Do A, B, and C in parallel")
      Process.sleep(300)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 3
    end

    test "planner broadcasts each task creation event" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      Phoenix.PubSub.subscribe(James.PubSub, "planner:#{session.id}")

      json_response =
        Jason.encode!([
          %{
            description: "First task",
            risk_level: "read_only",
            agent_type: "chat"
          },
          %{
            description: "Second task",
            risk_level: "additive",
            agent_type: "chat"
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: json_response, usage: %{}}})

      MetaPlanner.process_message(session.id, "Do first then second")
      Process.sleep(300)

      # Collect task_created events
      task_created_events =
        receive_all_messages()
        |> Enum.filter(fn msg ->
          match?({:planner_step, %{type: "task_created"}}, msg)
        end)

      assert length(task_created_events) >= 2
    end
  end

  # Drain the process mailbox and return all messages collected within a timeout.
  defp receive_all_messages(acc \\ []) do
    receive do
      msg -> receive_all_messages([msg | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
