defmodule James.Tasks do
  @moduledoc """
  Manages agent tasks and their lifecycle.
  """

  import Ecto.Query
  alias James.Repo
  alias James.Tasks.Task

  def list_tasks(opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    status = Keyword.get(opts, :status)
    risk_level = Keyword.get(opts, :risk_level)

    query = from t in Task, order_by: [desc: t.inserted_at]

    query = if session_id, do: from(t in query, where: t.session_id == ^session_id), else: query
    query = if status, do: from(t in query, where: t.status == ^status), else: query
    query = if risk_level, do: from(t in query, where: t.risk_level == ^risk_level), else: query

    Repo.all(query)
  end

  def get_task(id), do: Repo.get(Task, id)

  def get_task!(id), do: Repo.get!(Task, id) |> Repo.preload([:sub_tasks])

  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def approve_task(%Task{} = task) do
    task
    |> Task.changeset(%{status: "approved"})
    |> Repo.update()
  end

  def reject_task(%Task{} = task) do
    task
    |> Task.changeset(%{status: "rejected"})
    |> Repo.update()
  end

  def update_task_status(%Task{} = task, status) do
    attrs = %{status: status}

    attrs =
      if status == "completed", do: Map.put(attrs, :completed_at, DateTime.utc_now()), else: attrs

    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end
end
