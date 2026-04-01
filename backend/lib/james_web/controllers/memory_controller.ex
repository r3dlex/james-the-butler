defmodule JamesWeb.MemoryController do
  use Phoenix.Controller, formats: [:json]

  alias James.Memories

  def index(conn, params) do
    user = conn.assigns.current_user

    memories =
      case Map.get(params, "q") do
        nil ->
          opts = [
            limit: String.to_integer(Map.get(params, "limit", "50")),
            source_session_id: Map.get(params, "source_session_id")
          ]

          Memories.list_memories(user.id, opts)

        query_string ->
          Memories.search_text(user.id, query_string)
      end

    conn |> json(%{memories: Enum.map(memories, &memory_json/1)})
  end

  def update(conn, %{"id" => id} = params) do
    memory = Memories.get_memory!(id)

    case Memories.update_memory(memory, Map.take(params, ["content"])) do
      {:ok, updated} ->
        conn |> json(%{memory: memory_json(updated)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  rescue
    Ecto.NoResultsError ->
      conn |> put_status(:not_found) |> json(%{error: "not found"})
  end

  def delete(conn, %{"id" => id}) do
    memory = Memories.get_memory!(id)
    {:ok, _} = Memories.delete_memory(memory)
    conn |> json(%{ok: true})
  rescue
    Ecto.NoResultsError ->
      conn |> put_status(:not_found) |> json(%{error: "not found"})
  end

  defp memory_json(m) do
    %{
      id: m.id,
      content: m.content,
      source_session_id: m.source_session_id,
      inserted_at: m.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
