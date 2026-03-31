defmodule JamesWeb.TaskController do
  use Phoenix.Controller, formats: [:json]

  alias James.{Tasks, Sessions}
  alias James.OpenClaw.Orchestrator

  def index(conn, params) do
    opts = [
      session_id: Map.get(params, "session_id"),
      status: Map.get(params, "status"),
      risk_level: Map.get(params, "risk_level")
    ]
    tasks = Tasks.list_tasks(opts)
    conn |> json(%{tasks: Enum.map(tasks, &task_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Tasks.get_task(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      task -> conn |> json(%{task: task_json(task)})
    end
  end

  def approve(conn, %{"id" => id}) do
    with task when not is_nil(task) <- Tasks.get_task(id),
         {:ok, updated} <- Tasks.approve_task(task) do
      Phoenix.PubSub.broadcast(James.PubSub, "session:#{task.session_id}", {:task_updated, updated})

      # Dispatch approved task to OpenClaw for execution
      session = Sessions.get_session(task.session_id)
      if session do
        {:ok, running} = Tasks.update_task_status(updated, "running")
        Orchestrator.dispatch_task(running, session)
      end

      conn |> json(%{task: task_json(updated)})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def reject(conn, %{"id" => id}) do
    with task when not is_nil(task) <- Tasks.get_task(id),
         {:ok, updated} <- Tasks.reject_task(task) do
      Phoenix.PubSub.broadcast(James.PubSub, "session:#{task.session_id}", {:task_updated, updated})
      conn |> json(%{task: task_json(updated)})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  defp task_json(task) do
    %{
      id: task.id,
      session_id: task.session_id,
      parent_task_id: task.parent_task_id,
      description: task.description,
      risk_level: task.risk_level,
      status: task.status,
      host_id: task.host_id,
      inserted_at: task.inserted_at,
      completed_at: task.completed_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
