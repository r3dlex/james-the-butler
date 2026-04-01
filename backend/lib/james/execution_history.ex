defmodule James.ExecutionHistory do
  @moduledoc """
  Records structured logs and narrative summaries of agent execution for
  audit, replay, and learning purposes.
  """

  import Ecto.Query
  alias James.ExecutionHistory.Entry
  alias James.Repo

  @doc """
  Records a single action taken during a session.

  ## Parameters

    - `session_id` – UUID of the session
    - `action_type` – string label such as `"tool_call"`, `"file_read"`, `"decision"`
    - `payload` – arbitrary map of action-specific data

  Returns `{:ok, entry}` or `{:error, changeset}`.
  """
  def log_action(session_id, action_type, payload \\ %{}) do
    create_entry(%{session_id: session_id, action_type: action_type, payload: payload})
  end

  def list_entries(opts \\ []) do
    session_id = Keyword.get(opts, :session_id)

    query = from e in Entry, order_by: [asc: e.inserted_at]

    query =
      if session_id, do: from(e in query, where: e.session_id == ^session_id), else: query

    Repo.all(query)
  end

  def get_entry(id), do: Repo.get(Entry, id)

  def get_entry!(id), do: Repo.get!(Entry, id)

  def create_entry(attrs) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the number of execution history entries for `session_id`.
  """
  def entry_count(session_id) do
    Repo.aggregate(from(e in Entry, where: e.session_id == ^session_id), :count)
  end

  def update_narrative(%Entry{} = entry, narrative) do
    entry
    |> Entry.changeset(%{narrative_summary: narrative})
    |> Repo.update()
  end
end
