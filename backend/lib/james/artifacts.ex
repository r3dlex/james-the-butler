defmodule James.Artifacts do
  @moduledoc """
  Manages session artifacts — files, images, code, and documents produced during task execution.
  """

  import Ecto.Query
  alias James.Artifacts.Artifact
  alias James.Repo

  def list_artifacts(opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    task_id = Keyword.get(opts, :task_id)
    deliverable_only = Keyword.get(opts, :deliverable_only, false)
    uncleaned_only = Keyword.get(opts, :uncleaned_only, false)

    query = from a in Artifact, order_by: [desc: a.inserted_at]

    query = if session_id, do: from(a in query, where: a.session_id == ^session_id), else: query
    query = if task_id, do: from(a in query, where: a.task_id == ^task_id), else: query

    query =
      if deliverable_only, do: from(a in query, where: a.is_deliverable == true), else: query

    query = if uncleaned_only, do: from(a in query, where: is_nil(a.cleaned_at)), else: query

    Repo.all(query)
  end

  def get_artifact(id), do: Repo.get(Artifact, id)

  def get_artifact!(id), do: Repo.get!(Artifact, id)

  def create_artifact(attrs) do
    struct(Artifact)
    |> Artifact.changeset(attrs)
    |> Repo.insert()
  end

  def mark_cleaned(artifact) do
    artifact
    |> Artifact.changeset(%{cleaned_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def clean_task_artifacts(task_id) do
    now = DateTime.utc_now()

    {count, _} =
      from(a in Artifact,
        where: a.task_id == ^task_id and is_nil(a.cleaned_at) and a.is_deliverable == false
      )
      |> Repo.update_all(set: [cleaned_at: now])

    {:ok, count}
  end
end
