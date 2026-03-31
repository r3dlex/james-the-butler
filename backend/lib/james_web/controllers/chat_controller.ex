defmodule JamesWeb.ChatController do
  @moduledoc """
  Proxies chat messages to the configured Anthropic-compatible API (e.g. MiniMax).
  """

  use Phoenix.Controller, formats: [:json]

  def create(conn, %{"messages" => messages}) do
    api_key = System.get_env("ANTHROPIC_API_KEY")
    api_url = System.get_env("ANTHROPIC_API_URL", "https://api.anthropic.com")

    if is_nil(api_key) do
      conn
      |> put_status(500)
      |> json(%{error: "ANTHROPIC_API_KEY not configured"})
    else
      body =
        Jason.encode!(%{
          model: System.get_env("ANTHROPIC_MODEL", "claude-sonnet-4-20250514"),
          max_tokens: 1024,
          messages: messages
        })

      case Req.post("#{api_url}/v1/messages",
             body: body,
             headers: [
               {"content-type", "application/json"},
               {"x-api-key", api_key},
               {"anthropic-version", "2023-06-01"}
             ],
             receive_timeout: 60_000
           ) do
        {:ok, %{status: 200, body: resp_body}} ->
          json(conn, resp_body)

        {:ok, %{status: status, body: resp_body}} ->
          conn
          |> put_status(status)
          |> json(%{error: "API returned #{status}", detail: resp_body})

        {:error, reason} ->
          conn
          |> put_status(502)
          |> json(%{error: "Failed to reach LLM API", detail: inspect(reason)})
      end
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing 'messages' parameter"})
  end
end
