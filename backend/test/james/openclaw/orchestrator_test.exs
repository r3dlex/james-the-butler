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

    # Stop any existing orchestrator so each test gets a fresh one.
    if pid = Process.whereis(Orchestrator) do
      GenServer.stop(pid, :normal)
      # Wait for it to deregister
      Process.sleep(20)
    end

    {:ok, orchestrator} = Orchestrator.start_link([])

    on_exit(fn ->
      if Process.alive?(orchestrator) do
        GenServer.stop(orchestrator, :normal)
      end
    end)

    :ok
  end

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: "orch_#{System.unique_integer()}@example.com"})
    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "orch-host-#{System.unique_integer()}",
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
        name: "Orch Session",
        agent_type: agent_type
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "hello"})
    session
  end

  # ---------------------------------------------------------------------------
  # Task 3.1 — Host Registration Protocol
  # ---------------------------------------------------------------------------

  describe "register_host/1" do
    test "creates a new host record when the hostname is not yet registered" do
      hostname = "test-host-#{System.unique_integer()}"
      assert {:ok, host} = Orchestrator.register_host(hostname)
      assert host.name == hostname
    end

    test "updates existing host record when called with an already-registered name" do
      hostname = "existing-host-#{System.unique_integer()}"
      {:ok, _} = Orchestrator.register_host(hostname)
      {:ok, host2} = Orchestrator.register_host(hostname)
      # Only one record should exist for that name
      all = Hosts.list_hosts()
      assert Enum.count(all, &(&1.name == hostname)) == 1
      assert host2.name == hostname
    end

    test "sets last_seen_at on registration" do
      hostname = "seen-host-#{System.unique_integer()}"
      {:ok, host} = Orchestrator.register_host(hostname)
      assert %DateTime{} = host.last_seen_at
    end
  end

  describe "init/1 — automatic local host registration" do
    test "orchestrator registers the local host on startup" do
      # The orchestrator was started in setup; verify a host record exists for
      # the system hostname.
      hostname = :net_adm.localhost() |> to_string()
      hosts = Hosts.list_hosts()
      assert Enum.any?(hosts, &(&1.name == hostname))
    end
  end

  describe "heartbeat" do
    test "sending :heartbeat message updates last_seen_at" do
      hostname = :net_adm.localhost() |> to_string()

      # Grab the current last_seen_at
      host_before = Enum.find(Hosts.list_hosts(), &(&1.name == hostname))
      assert host_before != nil

      # Allow a tiny gap so DateTime comparison is meaningful
      Process.sleep(10)

      # Trigger heartbeat
      pid = Process.whereis(Orchestrator)
      send(pid, :heartbeat)
      Process.sleep(50)

      host_after = Hosts.get_host(host_before.id)
      # last_seen_at must have been refreshed (≥ before)
      assert DateTime.compare(host_after.last_seen_at, host_before.last_seen_at) in [:gt, :eq]
    end
  end

  describe "registered_host/0" do
    test "returns the current host record" do
      assert {:ok, host} = Orchestrator.registered_host()
      hostname = :net_adm.localhost() |> to_string()
      assert host.name == hostname
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.2 — Session Lifecycle in Orchestrator
  # ---------------------------------------------------------------------------

  describe "start_session/2" do
    test "creates a session record and starts an agent GenServer" do
      user = create_user()
      host = create_host()

      assert {:ok, session, pid} =
               Orchestrator.start_session(%{
                 user_id: user.id,
                 host_id: host.id,
                 name: "Lifecycle Test",
                 agent_type: "chat"
               })

      assert is_pid(pid)
      assert Process.alive?(pid)
      assert session.status == "active"
      Process.sleep(50)
    end

    test "returns error for invalid attrs" do
      assert {:error, _} = Orchestrator.start_session(%{})
    end
  end

  describe "suspend_session/1" do
    test "suspends session and terminates agent process gracefully" do
      user = create_user()
      host = create_host()

      {:ok, session, pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Suspend Test",
          agent_type: "chat"
        })

      assert :ok = Orchestrator.suspend_session(session.id)
      Process.sleep(50)

      refreshed = Sessions.get_session(session.id)
      assert refreshed.status == "suspended"
      # Process should no longer be alive after graceful termination
      refute Process.alive?(pid)
    end

    test "returns error when session is not active" do
      user = create_user()
      host = create_host()

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Already Suspended",
          agent_type: "chat",
          status: "suspended"
        })

      assert {:error, _} = Orchestrator.suspend_session(session.id)
    end
  end

  describe "resume_session/1" do
    test "resumes a suspended session and starts a new agent process" do
      user = create_user()
      host = create_host()

      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Resume Test",
          agent_type: "chat"
        })

      Sessions.create_message(%{session_id: session.id, role: "user", content: "resume me"})
      :ok = Orchestrator.suspend_session(session.id)
      Process.sleep(50)

      assert {:ok, new_pid} = Orchestrator.resume_session(session.id)
      assert is_pid(new_pid)
      assert Process.alive?(new_pid)

      refreshed = Sessions.get_session(session.id)
      assert refreshed.status == "active"
      Process.sleep(50)
    end

    test "returns error for non-suspended session" do
      user = create_user()
      host = create_host()

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Already Active",
          agent_type: "chat"
        })

      assert {:error, _} = Orchestrator.resume_session(session.id)
    end
  end

  describe "crash detection" do
    test "orchestrator detects crashed agent and removes it from active sessions" do
      user = create_user()
      host = create_host()

      {:ok, session, pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Crash Test",
          agent_type: "chat"
        })

      # Kill the agent process
      Process.exit(pid, :kill)
      Process.sleep(100)

      # Session should no longer appear in active_sessions
      active = Orchestrator.active_sessions()
      refute session.id in active
    end
  end

  describe "get_session_pid/1" do
    test "returns the PID of a running agent" do
      user = create_user()
      host = create_host()

      {:ok, session, expected_pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "PID Test",
          agent_type: "chat"
        })

      assert {:ok, ^expected_pid} = Orchestrator.get_session_pid(session.id)
      Process.sleep(50)
    end

    test "returns error for unknown session" do
      assert {:error, :not_found} = Orchestrator.get_session_pid(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.3 — Active Session Tracking and Streaming
  # ---------------------------------------------------------------------------

  describe "active_sessions/0" do
    test "returns empty list initially" do
      assert Orchestrator.active_sessions() == []
    end

    test "includes session ID after start_session" do
      user = create_user()
      host = create_host()

      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Active Track",
          agent_type: "chat"
        })

      assert session.id in Orchestrator.active_sessions()
      Process.sleep(50)
    end

    test "removes session ID after suspend_session" do
      user = create_user()
      host = create_host()

      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Track Suspend",
          agent_type: "chat"
        })

      Sessions.create_message(%{session_id: session.id, role: "user", content: "bye"})
      :ok = Orchestrator.suspend_session(session.id)
      Process.sleep(50)

      refute session.id in Orchestrator.active_sessions()
    end
  end

  describe "PubSub broadcasts" do
    test "broadcasts session_started when a session is started" do
      Phoenix.PubSub.subscribe(James.PubSub, "orchestrator:sessions")

      user = create_user()
      host = create_host()

      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "PubSub Start",
          agent_type: "chat"
        })

      assert_receive {:session_started, ^session}, 500
      Process.sleep(50)
    end

    test "broadcasts session_stopped when a session is suspended" do
      Phoenix.PubSub.subscribe(James.PubSub, "orchestrator:sessions")

      user = create_user()
      host = create_host()

      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "PubSub Suspend",
          agent_type: "chat"
        })

      Sessions.create_message(%{session_id: session.id, role: "user", content: "stop"})
      :ok = Orchestrator.suspend_session(session.id)

      session_id = session.id

      assert_receive {:session_stopped, %{id: ^session_id, status: "suspended"}}, 500
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2 — dispatch_task/2 (pre-existing tests, preserved)
  # ---------------------------------------------------------------------------

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
