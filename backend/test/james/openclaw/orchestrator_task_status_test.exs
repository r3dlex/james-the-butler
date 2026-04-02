defmodule James.OpenClaw.OrchestratorTaskStatusTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.OpenClaw.Orchestrator
  alias James.OpenClaw.Supervisor, as: AgentSupervisor
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()

    if is_nil(Process.whereis(AgentSupervisor)) do
      {:ok, _} = AgentSupervisor.start_link([])
    end

    # Stop any existing orchestrator so each test gets a fresh one.
    if pid = Process.whereis(Orchestrator) do
      GenServer.stop(pid, :normal)
      Process.sleep(20)
    end

    {:ok, orchestrator} = Orchestrator.start_link([])

    on_exit(fn ->
      try do
        if Process.alive?(orchestrator) do
          GenServer.stop(orchestrator, :normal)
        end
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  defp create_user do
    {:ok, user} =
      Accounts.create_user(%{email: "task_status_#{System.unique_integer()}@example.com"})

    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "task-status-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9000"
      })

    host
  end

  defp create_session(agent_type \\ "chat") do
    user = create_user()
    host = create_host()

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Task Status Session",
        agent_type: agent_type
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "hello"})
    session
  end

  # ---------------------------------------------------------------------------
  # Issue 4: Task status updated when agent process exits normally
  # ---------------------------------------------------------------------------

  describe "task status on agent normal exit" do
    test "when agent process exits normally, task status is updated to completed" do
      session = create_session("chat")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "normal exit task"})

      assert task.status == "pending"

      :ok = Orchestrator.dispatch_task(task, session)
      Process.sleep(400)

      refreshed = Tasks.get_task(task.id)
      assert refreshed != nil

      assert refreshed.status == "completed",
             "Expected task status 'completed' after normal agent exit, got: #{refreshed.status}"
    end
  end

  # ---------------------------------------------------------------------------
  # Issue 4: Orchestrator DOWN handler updates task status to "failed" on crash
  #
  # We simulate a crash by directly sending a DOWN message to the orchestrator
  # with a non-normal reason, bypassing the agent altogether. This way the
  # orchestrator's DOWN handler is the ONLY code path that could update the status.
  # ---------------------------------------------------------------------------

  describe "task status on agent crash (DOWN handler)" do
    test "when orchestrator receives a non-normal DOWN for a task agent, it sets status to failed" do
      session = create_session("chat")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "crash test"})

      assert task.status == "pending"

      orch_pid = Process.whereis(Orchestrator)
      assert is_pid(orch_pid)

      # Spawn a dummy process monitored by the orchestrator
      dummy_pid = spawn(fn -> Process.sleep(:infinity) end)

      # Monitor from the orchestrator process so the DOWN goes there
      dummy_ref =
        :sys.replace_state(orch_pid, fn state ->
          ref = Process.monitor(dummy_pid)
          entry = %{task_id: task.id, session_id: session.id, pid: dummy_pid}
          %{state | active_tasks: Map.put(state.active_tasks, ref, entry)}
        end)
        # replace_state returns the new state — extract the ref
        |> Map.get(:active_tasks)
        |> Map.keys()
        |> List.last()

      _ = dummy_ref

      # Kill the dummy process — this sends a DOWN to whoever monitors it (the orchestrator)
      Process.exit(dummy_pid, :kill)
      Process.sleep(200)

      refreshed = Tasks.get_task(task.id)
      assert refreshed != nil

      assert refreshed.status == "failed",
             "Expected orchestrator DOWN handler to set task status 'failed', got: #{refreshed.status}"
    end

    test "when orchestrator receives a normal DOWN for a task agent, it sets status to completed" do
      session = create_session("chat")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "normal exit test"})

      assert task.status == "pending"

      orch_pid = Process.whereis(Orchestrator)
      assert is_pid(orch_pid)

      # Spawn a dummy process that exits normally on its own
      parent = self()

      dummy_pid =
        spawn(fn ->
          receive do
            :go -> :ok
          end

          send(parent, :dummy_exiting)
        end)

      # Have the orchestrator monitor the dummy process
      :sys.replace_state(orch_pid, fn state ->
        ref = Process.monitor(dummy_pid)
        entry = %{task_id: task.id, session_id: session.id, pid: dummy_pid}
        %{state | active_tasks: Map.put(state.active_tasks, ref, entry)}
      end)

      # Trigger the dummy process to exit normally
      send(dummy_pid, :go)
      assert_receive :dummy_exiting, 500

      # Wait for orchestrator to process the DOWN
      Process.sleep(200)

      refreshed = Tasks.get_task(task.id)
      assert refreshed != nil

      assert refreshed.status == "completed",
             "Expected orchestrator DOWN handler to set task status 'completed', got: #{refreshed.status}"
    end
  end
end
