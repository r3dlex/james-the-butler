defmodule James.OpenClaw.Orchestrator do
  @moduledoc """
  Local orchestrator GenServer. One per host.
  Receives tasks from the meta-planner and dispatches them to agent workers
  via the OpenClaw DynamicSupervisor.

  Also manages host registration, heartbeating, and the lifecycle of
  named sessions (start / suspend / resume).
  """

  use GenServer

  alias James.Agents.{
    BrowserAgent,
    ChatAgent,
    CodeAgent,
    DesktopAgent,
    ResearchAgent,
    SecurityAgent
  }

  alias James.{Hosts, Sessions}
  alias James.OpenClaw.Supervisor, as: AgentSupervisor

  @heartbeat_interval :timer.seconds(30)

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Register (or upsert) a host by hostname. Returns `{:ok, host}`."
  def register_host(hostname) do
    GenServer.call(__MODULE__, {:register_host, hostname})
  end

  @doc "Return the current host record for this node."
  def registered_host do
    GenServer.call(__MODULE__, :registered_host)
  end

  @doc """
  Create a session record from `attrs` and start an agent process for it.
  Returns `{:ok, session, pid}` or `{:error, reason}`.
  """
  def start_session(attrs) do
    GenServer.call(__MODULE__, {:start_session, attrs})
  end

  @doc """
  Suspend an active session: update DB status, stop the agent process.
  Returns `:ok` or `{:error, reason}`.
  """
  def suspend_session(session_id) do
    GenServer.call(__MODULE__, {:suspend_session, session_id})
  end

  @doc """
  Resume a suspended session: update DB status, start a fresh agent process.
  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  def resume_session(session_id) do
    GenServer.call(__MODULE__, {:resume_session, session_id})
  end

  @doc "Return the PID for a running session agent, or `{:error, :not_found}`."
  def get_session_pid(session_id) do
    GenServer.call(__MODULE__, {:get_session_pid, session_id})
  end

  @doc "Return the list of currently active session IDs."
  def active_sessions do
    GenServer.call(__MODULE__, :active_sessions)
  end

  @doc "Dispatch a task to the appropriate agent worker."
  def dispatch_task(task, session) do
    GenServer.cast(__MODULE__, {:dispatch, task, session})
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    hostname = local_hostname()

    {:ok, host} = upsert_host(hostname)

    schedule_heartbeat()

    state = %{
      host: host,
      # %{session_id => %{pid: pid, ref: ref}}
      active_sessions: %{},
      # %{ref => session_id}  — for DOWN handling from dispatch_task
      active_tasks: %{}
    }

    {:ok, state}
  end

  # ---- Host registration ----

  @impl true
  def handle_call({:register_host, hostname}, _from, state) do
    case upsert_host(hostname) do
      {:ok, host} -> {:reply, {:ok, host}, state}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call(:registered_host, _from, state) do
    {:reply, {:ok, state.host}, state}
  end

  # ---- Session lifecycle ----

  def handle_call({:start_session, attrs}, _from, state) do
    case Sessions.create_session(attrs) do
      {:ok, session} ->
        case start_agent_for_session(session) do
          {:ok, pid} ->
            ref = Process.monitor(pid)

            active =
              Map.put(state.active_sessions, session.id, %{pid: pid, ref: ref})

            broadcast_session_event(:session_started, session)

            {:reply, {:ok, session, pid}, %{state | active_sessions: active}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, changeset} ->
        {:reply, {:error, changeset}, state}
    end
  end

  def handle_call({:suspend_session, session_id}, _from, state) do
    case Sessions.get_session(session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> do_suspend_session(session, session_id, state)
    end
  end

  def handle_call({:resume_session, session_id}, _from, state) do
    case Sessions.get_session(session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> do_resume_session(session, session_id, state)
    end
  end

  def handle_call({:get_session_pid, session_id}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      %{pid: pid} -> {:reply, {:ok, pid}, state}
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:active_sessions, _from, state) do
    {:reply, Map.keys(state.active_sessions), state}
  end

  # ---- dispatch_task ----

  @impl true
  def handle_cast({:dispatch, task, session}, state) do
    agent_module = agent_for_type(session.agent_type)

    opts = [
      session_id: session.id,
      task_id: task.id,
      model: nil
    ]

    case AgentSupervisor.start_agent(agent_module, opts) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        active_tasks =
          Map.put(state.active_tasks, ref, %{
            task_id: task.id,
            session_id: session.id,
            pid: pid
          })

        {:noreply, %{state | active_tasks: active_tasks}}

      {:error, reason} ->
        case James.Tasks.get_task(task.id) do
          nil -> :ok
          t -> James.Tasks.update_task_status(t, "failed")
        end

        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session.id}",
          {:assistant_chunk, "[Agent failed to start: #{inspect(reason)}]"}
        )

        {:noreply, state}
    end
  end

  # ---- DOWN messages ----

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    # Could be from a dispatched task agent or a session agent
    {active_tasks, _} = Map.pop(state.active_tasks, ref)

    # Check active_sessions for a matching ref
    {session_id, _entry} =
      Enum.find(state.active_sessions, {nil, nil}, fn {_id, entry} -> entry.ref == ref end)

    active_sessions =
      if session_id do
        Map.delete(state.active_sessions, session_id)
      else
        state.active_sessions
      end

    _ = pid

    {:noreply, %{state | active_tasks: active_tasks || %{}, active_sessions: active_sessions}}
  end

  def handle_info(:heartbeat, state) do
    updated_host = do_heartbeat(state.host)
    schedule_heartbeat()
    {:noreply, %{state | host: updated_host}}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp local_hostname do
    :net_adm.localhost() |> to_string()
  end

  defp upsert_host(hostname) do
    now = DateTime.utc_now()

    case Hosts.list_hosts() |> Enum.find(&(&1.name == hostname)) do
      nil ->
        Hosts.create_host(%{name: hostname, last_seen_at: now, status: "online"})

      existing ->
        Hosts.update_host(existing, %{last_seen_at: now, status: "online"})
    end
  end

  defp do_heartbeat(host) do
    case Hosts.heartbeat(host) do
      {:ok, updated} -> updated
      {:error, _} -> host
    end
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  defp start_agent_for_session(session) do
    agent_module = agent_for_type(session.agent_type)

    opts = [
      session_id: session.id,
      model: nil
    ]

    AgentSupervisor.start_agent(agent_module, opts)
  end

  defp pop_active_session(active_sessions, session_id) do
    {entry, remaining} = Map.pop(active_sessions, session_id)
    {remaining, entry}
  end

  defp broadcast_session_event(event, session) do
    Phoenix.PubSub.broadcast(
      James.PubSub,
      "orchestrator:sessions",
      {event, session}
    )
  end

  defp do_suspend_session(session, session_id, state) do
    case Sessions.suspend_session(session) do
      {:ok, updated_session} ->
        {active, entry} = pop_active_session(state.active_sessions, session_id)
        stop_agent_if_alive(entry)
        broadcast_session_event(:session_stopped, updated_session)
        {:reply, :ok, %{state | active_sessions: active}}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  defp do_resume_session(session, session_id, state) do
    case Sessions.resume_session(session) do
      {:ok, resumed_session} ->
        register_resumed_agent(resumed_session, session_id, state)

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  defp register_resumed_agent(resumed_session, session_id, state) do
    case start_agent_for_session(resumed_session) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        active = Map.put(state.active_sessions, session_id, %{pid: pid, ref: ref})
        broadcast_session_event(:session_started, resumed_session)
        {:reply, {:ok, pid}, %{state | active_sessions: active}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp stop_agent_if_alive(nil), do: :ok

  defp stop_agent_if_alive(%{pid: pid, ref: ref}) do
    if Process.alive?(pid) do
      Process.demonitor(ref, [:flush])
      GenServer.stop(pid, :normal)
    end
  end

  defp agent_for_type("chat"), do: ChatAgent
  defp agent_for_type("code"), do: CodeAgent
  defp agent_for_type("research"), do: ResearchAgent
  defp agent_for_type("security"), do: SecurityAgent
  defp agent_for_type("desktop"), do: DesktopAgent
  defp agent_for_type("browser"), do: BrowserAgent
  defp agent_for_type(_), do: ChatAgent
end
