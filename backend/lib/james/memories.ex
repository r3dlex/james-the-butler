defmodule James.Memories do
  @moduledoc """
  Manages user memories with vector similarity search.
  """

  import Ecto.Query
  alias James.Repo
  alias James.Memories.Memory

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

  def search_similar(user_id, embedding, limit \\ 10) do
    Repo.all(
      from m in Memory,
        where: m.user_id == ^user_id,
        order_by: fragment("embedding <=> ?", ^embedding),
        limit: ^limit
    )
  end
end
