defmodule James.Planner.MetaPlanner do
  @moduledoc """
  The Meta-Planner GenServer. Receives all user input, decomposes it into tasks
  using an LLM, tags each with a risk level, and dispatches to the local
  OpenClaw orchestrator.

  LLM decomposition (Phase 4):
  - Sends a decomposition prompt to the configured LLM provider.
  - Expects the LLM to reply with a JSON array of task objects.
  - Falls back to a single "Generate response" task when parsing fails.

  For v1 (single-host), all tasks dispatch locally.
  """

  use GenServer

  alias James.{ExecutionMode, Sessions, Tasks}
  alias James.LLMProvider
  alias James.OpenClaw.Orchestrator

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submit a user message for planning and execution.
  The planner will decompose, create tasks, and dispatch to OpenClaw.
  """
  def process_message(session_id, message) do
    GenServer.cast(__MODULE__, {:process_message, session_id, message})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process_message, session_id, message}, state) do
    session = Sessions.get_session(session_id)

    if session do
      broadcast_planner_step(session_id, %{
        type: "decomposing",
        description: "Analyzing input and creating tasks..."
      })

      task_specs = decompose_message(session, message)
      dispatch_task_specs(session, task_specs)
    end

    {:noreply, state}
  end

  # --- Private ---

  defp dispatch_task_specs(session, task_specs) do
    all_parallel? = Enum.all?(task_specs, fn spec -> Map.get(spec, :parallel, false) end)

    if all_parallel? and length(task_specs) > 1 do
      dispatch_parallel(session, task_specs)
    else
      Enum.each(task_specs, &dispatch_single(session, &1))
    end
  end

  # Dispatch a list of task specs concurrently using Task.async_stream.
  defp dispatch_parallel(session, task_specs) do
    task_specs
    |> Task.async_stream(
      fn spec -> dispatch_single(session, spec) end,
      max_concurrency: length(task_specs),
      timeout: 30_000
    )
    |> Stream.run()
  end

  defp dispatch_single(session, task_attrs) do
    case Tasks.create_task(task_attrs) do
      {:ok, task} ->
        broadcast_planner_step(session.id, %{
          type: "task_created",
          task: %{
            id: task.id,
            description: task.description,
            risk_level: task.risk_level,
            status: task.status
          }
        })

        broadcast_task_creation(task)

        tasks = Tasks.list_tasks(session_id: session.id)
        broadcast_task_list(session.id, tasks)

        execution_mode = ExecutionMode.resolve(session)
        dispatch_or_gate(session.id, task, session, execution_mode)

      {:error, _changeset} ->
        broadcast_planner_step(session.id, %{
          type: "error",
          description: "Failed to create task"
        })
    end
  end

  defp dispatch_or_gate(session_id, task, _session, "confirmed")
       when task.risk_level == "destructive" do
    {:ok, _} = Tasks.update_task_status(task, "pending")

    broadcast_planner_step(session_id, %{
      type: "awaiting_approval",
      task_id: task.id,
      description: "Destructive task requires approval"
    })
  end

  defp dispatch_or_gate(session_id, task, session, _execution_mode) do
    {:ok, updated_task} = Tasks.update_task_status(task, "running")
    Orchestrator.dispatch_task(updated_task, session)

    broadcast_planner_step(session_id, %{
      type: "dispatched",
      task_id: task.id,
      description: "Task dispatched to agent"
    })
  end

  # ---------------------------------------------------------------------------
  # LLM-driven decomposition
  # ---------------------------------------------------------------------------

  @decomposition_prompt """
  You are a task decomposition assistant. Given the user message below, break it
  down into one or more concrete tasks.

  Return ONLY a JSON array (no surrounding text) where each element has:
  - "description": string — a clear, concise task description
  - "risk_level": one of "read_only", "additive", or "destructive"
  - "agent_type": one of "chat", "code", "research", "security"
  - "parallel": boolean — true if the task can run simultaneously with others

  If the message is a simple chat request, return a single-element array with
  agent_type "chat" and risk_level "read_only".

  User message:
  """

  defp decompose_message(session, message) do
    messages = [%{role: "user", content: @decomposition_prompt <> message}]

    case LLMProvider.configured().send_message(messages, []) do
      {:ok, %{content: content}} when is_binary(content) and content != "" ->
        parse_task_specs(content, session)

      _ ->
        [fallback_task_spec(session)]
    end
  end

  defp parse_task_specs(content, session) do
    case Jason.decode(content) do
      {:ok, tasks} when is_list(tasks) and tasks != [] ->
        Enum.map(tasks, fn spec -> build_task_attrs(spec, session) end)

      _ ->
        [fallback_task_spec(session)]
    end
  end

  defp build_task_attrs(spec, session) do
    risk_level = Map.get(spec, "risk_level", "read_only")
    parallel = Map.get(spec, "parallel", false)

    %{
      session_id: session.id,
      host_id: session.host_id,
      description: Map.get(spec, "description", "Generate response"),
      risk_level: valid_risk_level(risk_level),
      status: "pending",
      parallel: parallel
    }
  end

  defp fallback_task_spec(session) do
    %{
      session_id: session.id,
      host_id: session.host_id,
      description: "Generate response",
      risk_level: classify_risk(session.agent_type),
      status: "pending",
      parallel: false
    }
  end

  defp valid_risk_level(level) when level in ["read_only", "additive", "destructive"], do: level
  defp valid_risk_level(_), do: "read_only"

  defp classify_risk("chat"), do: "read_only"
  defp classify_risk("research"), do: "read_only"
  defp classify_risk("code"), do: "additive"
  defp classify_risk("desktop"), do: "destructive"
  defp classify_risk("browser"), do: "destructive"
  defp classify_risk(_), do: "read_only"

  # ---------------------------------------------------------------------------
  # Broadcasting helpers
  # ---------------------------------------------------------------------------

  defp broadcast_planner_step(session_id, step) do
    Phoenix.PubSub.broadcast(
      James.PubSub,
      "planner:#{session_id}",
      {:planner_step, step}
    )
  end

  defp broadcast_task_creation(task) do
    Phoenix.PubSub.broadcast(
      James.PubSub,
      "planner:tasks",
      {:task_created, %{id: task.id, description: task.description, risk_level: task.risk_level}}
    )
  end

  defp broadcast_task_list(session_id, tasks) do
    task_list =
      Enum.map(tasks, fn t ->
        %{
          id: t.id,
          description: t.description,
          status: t.status,
          risk_level: t.risk_level
        }
      end)

    Phoenix.PubSub.broadcast(
      James.PubSub,
      "planner:#{session_id}",
      {:task_list_updated, task_list}
    )
  end
end
