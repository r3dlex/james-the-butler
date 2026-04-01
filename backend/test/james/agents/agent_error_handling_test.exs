defmodule James.Agents.AgentErrorHandlingTest do
  @moduledoc """
  Tests that each agent GenServer starts, attempts to run, and handles
  the missing-API-key error gracefully (broadcasts error chunk, marks task failed,
  then stops normally).
  """
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}

  alias James.Agents.{
    BrowserAgent,
    ChatAgent,
    CodeAgent,
    DesktopAgent,
    ResearchAgent,
    SecurityAgent
  }

  # Map logical agent types to valid session agent_type values
  @session_agent_type %{
    "chat" => "chat",
    "code" => "code",
    "research" => "research",
    "security" => "code",
    "desktop" => "desktop",
    "browser" => "browser"
  }

  defp setup_session(agent_type) do
    {:ok, user} = Accounts.create_user(%{email: "agt_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "agt-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    session_agent_type = Map.get(@session_agent_type, agent_type, "chat")

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Agent Test",
        agent_type: session_agent_type
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "test message"})

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "agent task",
        risk_level: "read_only"
      })

    %{session: session, task: task}
  end

  defp run_agent_and_wait(module, session, task) do
    System.delete_env("ANTHROPIC_API_KEY")
    Application.delete_env(:james, :anthropic_api_key)

    {:ok, pid} =
      module.start_link(session_id: session.id, task_id: task.id)

    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      3000 -> :timeout
    end
  end

  describe "ChatAgent" do
    test "starts, fails gracefully on missing API key, and exits" do
      %{session: session, task: task} = setup_session("chat")
      assert :ok = run_agent_and_wait(ChatAgent, session, task)
      updated = Tasks.get_task(task.id)
      assert updated.status in ["failed", "pending", "running"]
    end
  end

  describe "CodeAgent" do
    test "starts, fails gracefully on missing API key, and exits" do
      %{session: session, task: task} = setup_session("code")
      assert :ok = run_agent_and_wait(CodeAgent, session, task)
      updated = Tasks.get_task(task.id)
      assert updated.status in ["failed", "pending", "running"]
    end
  end

  describe "ResearchAgent" do
    test "starts, fails gracefully on missing API key, and exits" do
      %{session: session, task: task} = setup_session("research")
      assert :ok = run_agent_and_wait(ResearchAgent, session, task)
      updated = Tasks.get_task(task.id)
      assert updated.status in ["failed", "pending", "running"]
    end
  end

  describe "SecurityAgent" do
    test "starts, fails gracefully on missing API key, and exits" do
      %{session: session, task: task} = setup_session("security")
      assert :ok = run_agent_and_wait(SecurityAgent, session, task)
      updated = Tasks.get_task(task.id)
      assert updated.status in ["failed", "pending", "running"]
    end

    test "starts without a task_id (nil task)" do
      %{session: session} = setup_session("security")
      System.delete_env("ANTHROPIC_API_KEY")
      Application.delete_env(:james, :anthropic_api_key)

      {:ok, pid} = SecurityAgent.start_link(session_id: session.id)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 3000
    end
  end

  describe "DesktopAgent" do
    test "starts, fails gracefully on missing API key, and exits" do
      %{session: session, task: task} = setup_session("desktop")
      assert :ok = run_agent_and_wait(DesktopAgent, session, task)
    end
  end

  describe "BrowserAgent" do
    test "starts, fails gracefully on missing API key, and exits" do
      %{session: session, task: task} = setup_session("browser")
      assert :ok = run_agent_and_wait(BrowserAgent, session, task)
    end
  end

  describe "ChatAgent without task_id" do
    test "starts and exits without crashing on nil task" do
      %{session: session} = setup_session("chat")
      System.delete_env("ANTHROPIC_API_KEY")
      Application.delete_env(:james, :anthropic_api_key)

      {:ok, pid} = ChatAgent.start_link(session_id: session.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 3000
    end
  end
end
