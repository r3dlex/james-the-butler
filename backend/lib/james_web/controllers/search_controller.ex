defmodule JamesWeb.SearchController do
  use Phoenix.Controller, formats: [:json]

  alias James.Search

  # GET /api/search?q=...&host_id=...&project_id=...&agent_type=...
  def index(conn, params) do
    user = conn.assigns.current_user
    query = Map.get(params, "q", "")

    if String.trim(query) == "" do
      conn |> json(%{results: []})
    else
      opts = [
        user_id: user.id,
        host_id: Map.get(params, "host_id"),
        project_id: Map.get(params, "project_id"),
        agent_type: Map.get(params, "agent_type"),
        limit: String.to_integer(Map.get(params, "limit", "20"))
      ]

      results = Search.search(query, opts)

      conn
      |> json(%{
        results:
          Enum.map(results, fn r ->
            %{
              session_id: r.session_id,
              session_name: r.session_name,
              agent_type: r.agent_type,
              host_id: r.host_id,
              excerpt: r.excerpt,
              last_used_at: r.last_used_at,
              source: r.source
            }
          end)
      })
    end
  end
end
