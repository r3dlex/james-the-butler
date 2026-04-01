defmodule James.Memories do
  @moduledoc """
  Manages user memories with vector similarity search.
  """

  import Ecto.Query
  alias James.Memories.Memory
  alias James.Repo
  alias James.Sessions.Session

  def list_memories(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    source_session_id = Keyword.get(opts, :source_session_id)

    query =
      from m in Memory,
        where: m.user_id == ^user_id,
        order_by: [desc: m.inserted_at],
        limit: ^limit

    query =
      if source_session_id do
        from m in query, where: m.source_session_id == ^source_session_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Returns all memories for a user without a default limit cap.
  """
  def list_memories_for_user(user_id) do
    Repo.all(
      from m in Memory,
        where: m.user_id == ^user_id,
        order_by: [desc: m.inserted_at]
    )
  end

  def get_memory!(id), do: Repo.get!(Memory, id)

  def create_memory(attrs) do
    %Memory{}
    |> Memory.changeset(attrs)
    |> Repo.insert()
  end

  def update_memory(%Memory{} = memory, attrs) do
    memory
    |> Memory.changeset(attrs)
    |> Repo.update()
  end

  def delete_memory(%Memory{} = memory) do
    Repo.delete(memory)
  end

  @doc """
  Searches memories using vector cosine distance.
  Accepts optional `project_id:` keyword to scope results to sessions
  belonging to a specific project.
  """
  def search_similar(user_id, embedding, limit \\ 10, opts \\ []) do
    project_id = Keyword.get(opts, :project_id)

    query =
      from m in Memory,
        where: m.user_id == ^user_id,
        order_by: fragment("embedding <=> ?", ^embedding),
        limit: ^limit

    query =
      if project_id do
        from m in query,
          join: s in Session,
          on: s.id == m.source_session_id,
          where: s.project_id == ^project_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Full-text ILIKE search over memory content.
  Returns memories whose content contains the query string (case-insensitive).
  """
  def search_text(user_id, query_string) when is_binary(query_string) do
    pattern = "%#{query_string}%"

    Repo.all(
      from m in Memory,
        where: m.user_id == ^user_id and ilike(m.content, ^pattern),
        order_by: [desc: m.inserted_at]
    )
  end
end
