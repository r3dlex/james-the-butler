defmodule James.ExecutionHistory do
  @moduledoc """
  Records structured logs and narrative summaries of agent execution for
  audit, replay, and learning purposes.
  """

  import Ecto.Query
  alias James.ExecutionHistory.Entry
  alias James.Repo

  def list_entries(opts \\ []) do
    session_id = Keyword.get(opts, :session_id)

    query = from e in Entry, order_by: [desc: e.inserted_at]

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

  def update_narrative(%Entry{} = entry, narrative) do
    entry
    |> Entry.changeset(%{narrative_summary: narrative})
    |> Repo.update()
  end
end
