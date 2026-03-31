defmodule James.OpenClaw.Orchestrator do
  @moduledoc """
  Local orchestrator GenServer. One per host.
  Receives tasks from the meta-planner and dispatches them to agent workers
  via the OpenClaw DynamicSupervisor.
  """

  use GenServer

  alias James.OpenClaw.Supervisor, as: AgentSupervisor
  alias James.Agents.{ChatAgent, CodeAgent, ResearchAgent, SecurityAgent, DesktopAgent, BrowserAgent}

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Dispatch a task to the appropriate agent worker.
  """
  def dispatch_task(task, session) do
    GenServer.cast(__MODULE__, {:dispatch, task, session})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{active_tasks: %{}}}
  end

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
        active = Map.put(state.active_tasks, ref, %{task_id: task.id, session_id: session.id, pid: pid})
        {:noreply, %{state | active_tasks: active}}

      {:error, reason} ->
        # Mark task as failed
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

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {_info, active} = Map.pop(state.active_tasks, ref)
    {:noreply, %{state | active_tasks: active}}
  end

  # --- Private ---

  defp agent_for_type("chat"), do: ChatAgent
  defp agent_for_type("code"), do: CodeAgent
  defp agent_for_type("research"), do: ResearchAgent
  defp agent_for_type("security"), do: SecurityAgent
  defp agent_for_type("desktop"), do: DesktopAgent
  defp agent_for_type("browser"), do: BrowserAgent
  defp agent_for_type(_), do: ChatAgent
end
