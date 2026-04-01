defmodule JamesCli.Client do
  @moduledoc """
  HTTP client for the James server REST API.

  All requests are authenticated via a Bearer token from config.
  """

  @doc "Lists sessions for the authenticated user."
  def list_sessions(config) do
    get(config, "/api/sessions")
  end

  @doc "Shows a single session."
  def get_session(config, id) do
    get(config, "/api/sessions/#{id}")
  end

  @doc "Creates a new session."
  def create_session(config, attrs) do
    post(config, "/api/sessions", attrs)
  end

  @doc "Sends a chat message to a session."
  def chat(config, session_id, message) do
    post(config, "/api/sessions/#{session_id}/chat", %{message: message})
  end

  @doc "Lists skills."
  def list_skills(config) do
    get(config, "/api/skills")
  end

  @doc "Lists memories."
  def list_memories(config) do
    get(config, "/api/memories")
  end

  @doc "Lists hosts."
  def list_hosts(config) do
    get(config, "/api/hosts")
  end

  # --- Internal ---

  defp get(config, path) do
    url = base_url(config) <> path

    case Req.get(url, headers: auth_headers(config)) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post(config, path, body) do
    url = base_url(config) <> path

    case Req.post(url, json: body, headers: auth_headers(config)) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config) do
    JamesCli.Config.get(config, ["server", "url"], "http://localhost:4000")
  end

  defp auth_headers(config) do
    token = JamesCli.Config.get(config, ["server", "token"])

    if token do
      [{"authorization", "Bearer #{token}"}]
    else
      []
    end
  end
end
