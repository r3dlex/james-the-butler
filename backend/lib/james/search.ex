defmodule James.Search do
  @moduledoc """
  Hybrid search across sessions using full-text (tsvector) and semantic (pgvector).
  Both indexes are queried in parallel. Results are merged and ranked by combined score.
  """

  import Ecto.Query
  alias James.Embeddings
  alias James.Repo
  alias James.Sessions.{Message, Session}

  @doc """
  Search across all sessions by title and content.
  Returns a list of result maps with session info and matching excerpts.

  Options:
    - `:user_id` — required, scopes to user's sessions
    - `:host_id` — filter by host
    - `:project_id` — filter by project
    - `:agent_type` — filter by agent type
    - `:limit` — max results (default 20)
  """
  def search(query_text, opts \\ []) do
    user_id = Keyword.fetch!(opts, :user_id)
    limit = Keyword.get(opts, :limit, 20)

    # Full-text search on sessions and messages
    text_results = fulltext_search(query_text, user_id, opts, limit)

    # Semantic search via pgvector (if embeddings available)
    semantic_results = semantic_search(query_text, user_id, opts, limit)

    # Merge and deduplicate by session ID, keeping highest-ranked
    merged =
      (text_results ++ semantic_results)
      |> Enum.uniq_by(& &1.session_id)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(limit)

    merged
  end

  defp fulltext_search(query_text, user_id, opts, limit) do
    tsquery = sanitize_tsquery(query_text)

    if tsquery == "" do
      []
    else
      # Search session titles
      session_results =
        from(s in Session,
          where: s.user_id == ^user_id and s.status != "archived",
          where: fragment("search_vector @@ to_tsquery('english', ?)", ^tsquery),
          select: %{
            session_id: s.id,
            session_name: s.name,
            agent_type: s.agent_type,
            host_id: s.host_id,
            excerpt: s.name,
            last_used_at: s.last_used_at,
            score: fragment("ts_rank(search_vector, to_tsquery('english', ?))", ^tsquery)
          },
          limit: ^limit
        )
        |> apply_filters(opts)
        |> Repo.all()
        |> Enum.map(&Map.put(&1, :source, :title))

      # Search message content
      message_results =
        from(m in Message,
          join: s in Session,
          on: m.session_id == s.id,
          where: s.user_id == ^user_id and s.status != "archived",
          where: fragment("m0.search_vector @@ to_tsquery('english', ?)", ^tsquery),
          select: %{
            session_id: s.id,
            session_name: s.name,
            agent_type: s.agent_type,
            host_id: s.host_id,
            excerpt:
              fragment(
                "ts_headline('english', m0.content, to_tsquery('english', ?), 'MaxWords=30,MinWords=15')",
                ^tsquery
              ),
            last_used_at: s.last_used_at,
            score: fragment("ts_rank(m0.search_vector, to_tsquery('english', ?))", ^tsquery)
          },
          order_by: [
            desc: fragment("ts_rank(m0.search_vector, to_tsquery('english', ?))", ^tsquery)
          ],
          limit: ^limit
        )
        |> Repo.all()
        |> Enum.map(&Map.put(&1, :source, :content))

      session_results ++ message_results
    end
  end

  defp semantic_search(query_text, user_id, _opts, limit) do
    case Embeddings.generate(query_text) do
      {:ok, embedding} ->
        from(m in James.Memories.Memory,
          join: s in Session,
          on: m.source_session_id == s.id,
          where: m.user_id == ^user_id,
          select: %{
            session_id: s.id,
            session_name: s.name,
            agent_type: s.agent_type,
            host_id: s.host_id,
            excerpt: m.content,
            last_used_at: s.last_used_at,
            score: fragment("1 - (embedding <=> ?)", ^embedding)
          },
          order_by: fragment("embedding <=> ?", ^embedding),
          limit: ^limit
        )
        |> Repo.all()
        |> Enum.map(&Map.put(&1, :source, :semantic))

      {:error, _} ->
        []
    end
  end

  defp apply_filters(query, opts) do
    query
    |> maybe_filter(:host_id, Keyword.get(opts, :host_id))
    |> maybe_filter(:project_id, Keyword.get(opts, :project_id))
    |> maybe_filter(:agent_type, Keyword.get(opts, :agent_type))
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, :host_id, val), do: from(s in query, where: s.host_id == ^val)
  defp maybe_filter(query, :project_id, val), do: from(s in query, where: s.project_id == ^val)
  defp maybe_filter(query, :agent_type, val), do: from(s in query, where: s.agent_type == ^val)

  defp sanitize_tsquery(text) do
    text
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" & ")
  end
end
