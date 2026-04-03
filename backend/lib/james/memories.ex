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
  Returns all memories for a user without a limit cap.
  Equivalent to `list_memories/2` with a very large limit.
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
  Searches memories using vector cosine distance when embeddings exist.
  Accepts optional `project_id:` keyword argument to scope results to
  sessions belonging to a specific project. Accepts optional `memory_types:`
  list to filter by one or more memory types.
  """
  def search_similar(user_id, embedding, limit \\ 10, opts \\ []) do
    project_id = Keyword.get(opts, :project_id)
    memory_types = Keyword.get(opts, :memory_types)

    query =
      from m in Memory,
        where: m.user_id == ^user_id

    query =
      if memory_types do
        from m in query, where: m.memory_type in ^memory_types
      else
        query
      end

    query =
      if project_id do
        from m in query,
          join: s in Session,
          on: s.id == m.source_session_id,
          where: s.project_id == ^project_id
      else
        query
      end

    from(m in query,
      order_by: fragment("embedding <=> ?", ^embedding),
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Searches recent memories by generating an embedding for the query text
  and performing vector similarity search. Accepts optional `memory_types:`
  list to filter by one or more memory types and `limit:` (default 5).
  """
  def get_recent_memories(user_id, query_text, opts \\ []) do
    with {:ok, embedding} <- James.Embeddings.generate(query_text) do
      search_similar(user_id, embedding, Keyword.get(opts, :limit, 5),
        memory_types: Keyword.get(opts, :memory_types)
      )
    end
  end

  @doc """
  Full-text search over memory content using ILIKE.
  Falls back for contexts where no embedding vector is available.
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
