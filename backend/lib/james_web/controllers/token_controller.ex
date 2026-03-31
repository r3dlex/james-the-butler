defmodule JamesWeb.TokenController do
  use Phoenix.Controller, formats: [:json]

  alias James.Tokens

  def usage(conn, params) do
    opts = [
      session_id: Map.get(params, "session_id"),
      model: Map.get(params, "model"),
      limit: String.to_integer(Map.get(params, "limit", "100"))
    ]

    entries = Tokens.list_usage(opts)
    conn |> json(%{usage: Enum.map(entries, &entry_json/1)})
  end

  def summary(conn, params) do
    opts = [session_id: Map.get(params, "session_id")]
    summary = Tokens.usage_summary(opts)
    conn |> json(%{summary: summary})
  end

  defp entry_json(e) do
    %{
      id: e.id,
      session_id: e.session_id,
      task_id: e.task_id,
      model: e.model,
      input_tokens: e.input_tokens,
      output_tokens: e.output_tokens,
      cost_usd: e.cost_usd,
      inserted_at: e.inserted_at
    }
  end
end
