defmodule James.Planner.MetaPlanner do
  @moduledoc """
  The Meta-Planner GenServer. Receives all user input, decomposes it into tasks,
  tags each with a risk level, and dispatches to the local OpenClaw orchestrator.

  For v1 (single-host), all tasks dispatch locally.
  """

  use GenServer

  alias James.{Tasks, Sessions, ExecutionMode}
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
      # Broadcast planner step: decomposing
      broadcast_planner_step(session_id, %{
        type: "decomposing",
        description: "Analyzing input and creating tasks..."
      })

      # For chat sessions, create a single task (the response)
      # More complex decomposition will come in Phase 2
      task_attrs = decompose_message(session, message)

      case Tasks.create_task(task_attrs) do
        {:ok, task} ->
          # Broadcast planner step: task created
          broadcast_planner_step(session_id, %{
            type: "task_created",
            task: %{
              id: task.id,
              description: task.description,
              risk_level: task.risk_level,
              status: task.status
            }
          })

          # Broadcast updated task list
          tasks = Tasks.list_tasks(session_id: session_id)
          broadcast_task_list(session_id, tasks)

          # Check execution mode — in confirmed mode, destructive tasks need approval
          execution_mode = ExecutionMode.resolve(session)

          if execution_mode == "confirmed" and task.risk_level == "destructive" do
            {:ok, _} = Tasks.update_task_status(task, "pending")

            broadcast_planner_step(session_id, %{
              type: "awaiting_approval",
              task_id: task.id,
              description: "Destructive task requires approval"
            })
          else
            # Direct mode or non-destructive: dispatch immediately
            {:ok, updated_task} = Tasks.update_task_status(task, "running")
            Orchestrator.dispatch_task(updated_task, session)

            broadcast_planner_step(session_id, %{
              type: "dispatched",
              task_id: task.id,
              description: "Task dispatched to agent"
            })
          end

        {:error, _changeset} ->
          broadcast_planner_step(session_id, %{
            type: "error",
            description: "Failed to create task"
          })
      end
    end

    {:noreply, state}
  end

  # --- Private ---

  defp decompose_message(session, _message) do
    # V1: Single-task decomposition for chat sessions
    # Future phases will use the LLM to decompose complex requests
    %{
      session_id: session.id,
      host_id: session.host_id,
      description: "Generate response",
      risk_level: classify_risk(session.agent_type),
      status: "pending"
    }
  end

  defp classify_risk("chat"), do: "read_only"
  defp classify_risk("research"), do: "read_only"
  defp classify_risk("code"), do: "additive"
  defp classify_risk("desktop"), do: "destructive"
  defp classify_risk("browser"), do: "destructive"
  defp classify_risk(_), do: "read_only"

  defp broadcast_planner_step(session_id, step) do
    Phoenix.PubSub.broadcast(
      James.PubSub,
      "planner:#{session_id}",
      {:planner_step, step}
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
