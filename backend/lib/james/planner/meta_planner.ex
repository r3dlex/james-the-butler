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
  alias James.Hooks.Dispatcher
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
      Dispatcher.fire(:user_prompt_submit, %{session_id: session_id, message: message})

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

    Dispatcher.fire(:permission_denied, %{
      session_id: session_id,
      task_id: task.id,
      risk_level: :destructive
    })

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

  @synthesis_rules """

  ## Synthesis Requirement

  When producing the final response for any task or set of tasks, you MUST
  synthesise findings into a coherent, direct answer rather than merely
  reporting what each sub-agent returned.

  ### Anti-patterns to avoid

  The following phrases indicate poor synthesis and MUST NOT appear in final
  responses:
  - "Based on your findings…"
  - "As the research agent found…"
  - "According to the sub-task result…"
  - "The agent reported that…"
  - "Tool X returned…"

  ### Continue vs. Spawn decision table

  | Condition                          | Action                          |
  |------------------------------------|---------------------------------|
  | Follow-up fits within context      | Continue in current session     |
  | New independent domain/goal        | Spawn dedicated sub-agent       |
  | Requires different agent_type      | Spawn with appropriate type     |
  | User explicitly requests isolation | Spawn new session               |
  | Clarification of prior message     | Continue in current session     |

  ### Verification requirements

  Before returning any synthesised result:
  1. Confirm all required sub-tasks have completed successfully.
  2. Resolve any contradictions between sub-task outputs.
  3. Ensure the response directly addresses the original user intent.
  4. Remove any raw tool output or intermediate agent commentary.
  """

  @decomposition_prompt_base """
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

  @decomposition_prompt @decomposition_prompt_base <> @synthesis_rules

  defp decompose_message(session, message) do
    # `message` may be a %Sessions.Message{} struct or a plain binary string.
    user_content = if is_struct(message), do: to_string(message.content), else: to_string(message)
    messages = [%{role: "user", content: @decomposition_prompt <> user_content}]

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
