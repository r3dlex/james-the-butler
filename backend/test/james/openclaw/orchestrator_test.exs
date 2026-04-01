defmodule James.OpenClaw.OrchestratorTest do
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

    if is_nil(Process.whereis(Orchestrator)) do
      {:ok, _} = Orchestrator.start_link([])
    end

    :ok
  end

  defp create_session(agent_type \\ "chat") do
    {:ok, user} = Accounts.create_user(%{email: "orch_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "orch-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9000"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Orch Session",
        agent_type: agent_type
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "hello"})
    session
  end

  describe "dispatch_task/2" do
    test "dispatches chat task without crashing" do
      session = create_session("chat")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "test"})
      # Should not raise
      assert :ok == Orchestrator.dispatch_task(task, session)
      Process.sleep(100)
    end

    test "dispatches code task without crashing" do
      session = create_session("code")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "code task"})
      assert :ok == Orchestrator.dispatch_task(task, session)
      Process.sleep(100)
    end

    test "dispatches research task without crashing" do
      session = create_session("research")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "research"})
      assert :ok == Orchestrator.dispatch_task(task, session)
      Process.sleep(100)
    end

    test "dispatches desktop task without crashing" do
      session = create_session("desktop")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "desktop"})
      assert :ok == Orchestrator.dispatch_task(task, session)
      Process.sleep(100)
    end

    test "dispatches browser task without crashing" do
      session = create_session("browser")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "browser"})
      assert :ok == Orchestrator.dispatch_task(task, session)
      Process.sleep(100)
    end

    test "dispatches unknown agent_type (falls back to chat) without crashing" do
      session = create_session("chat")
      # Use a task but pretend session has an unknown type by using a bare map
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "unknown"})
      fake_session = %{session | agent_type: "unknown_type"}
      assert :ok == Orchestrator.dispatch_task(task, fake_session)
      Process.sleep(100)
    end

    test "orchestrator process is still alive after dispatching" do
      session = create_session("chat")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "alive?"})
      Orchestrator.dispatch_task(task, session)
      Process.sleep(150)
      assert is_pid(Process.whereis(Orchestrator))
    end

    test "dispatches security task (agent_for_type fallback using fake session)" do
      session = create_session("code")
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "security scan"})
      fake_session = %{session | agent_type: "security"}
      assert :ok == Orchestrator.dispatch_task(task, fake_session)
      Process.sleep(150)
    end
  end
end
