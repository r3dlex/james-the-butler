defmodule JamesCli.Client do
  @moduledoc """
  HTTP client for the James server REST API.

  All requests are authenticated via a Bearer token from config.
  Falls back to Auth.load_token if no token in config.
  """

  alias JamesCli.Auth

  # Sessions
  def list_sessions(config), do: get(config, "/api/sessions")
  def get_session(config, id), do: get(config, "/api/sessions/#{id}")
  def create_session(config, attrs), do: post(config, "/api/sessions", attrs)
  def delete_session(config, id), do: delete(config, "/api/sessions/#{id}")

  def chat(config, session_id, message) do
    post(config, "/api/sessions/#{session_id}/messages", %{message: message})
  end

  # Tasks
  def list_tasks(config, session_id \\ nil) do
    path = if session_id, do: "/api/tasks?session_id=#{session_id}", else: "/api/tasks"
    get(config, path)
  end

  def get_task(config, id), do: get(config, "/api/tasks/#{id}")
  def approve_task(config, id), do: post(config, "/api/tasks/#{id}/approve", %{})
  def reject_task(config, id), do: post(config, "/api/tasks/#{id}/reject", %{})

  # Projects
  def list_projects(config), do: get(config, "/api/projects")
  def get_project(config, id), do: get(config, "/api/projects/#{id}")
  def create_project(config, attrs), do: post(config, "/api/projects", attrs)

  # Skills (settings)
  def list_skills(config), do: get(config, "/api/settings/skills")
  def create_skill(config, attrs), do: post(config, "/api/settings/skills", attrs)
  def delete_skill(config, id), do: delete(config, "/api/settings/skills/#{id}")

  # Hooks
  def list_hooks(config), do: get(config, "/api/hooks")
  def get_hook(config, id), do: get(config, "/api/hooks/#{id}")
  def create_hook(config, attrs), do: post(config, "/api/hooks", attrs)
  def update_hook(config, id, attrs), do: put(config, "/api/hooks/#{id}", attrs)
  def delete_hook(config, id), do: delete(config, "/api/hooks/#{id}")

  # Memories
  def list_memories(config), do: get(config, "/api/memories")

  # Hosts
  def list_hosts(config), do: get(config, "/api/hosts")
  def get_host(config, id), do: get(config, "/api/hosts/#{id}")

  # Auth
  def get_me(config), do: get(config, "/api/auth/me")

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

  defp put(config, path, body) do
    url = base_url(config) <> path

    case Req.put(url, json: body, headers: auth_headers(config)) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete(config, path) do
    url = base_url(config) <> path

    case Req.delete(url, headers: auth_headers(config)) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config) do
    JamesCli.Config.get(config, ["server", "url"], "http://localhost:4000")
  end

  defp auth_headers(config) do
    token =
      JamesCli.Config.get(config, ["server", "token"]) ||
        case Auth.load_token() do
          {:ok, t} -> t
          _ -> nil
        end

    if token do
      [{"authorization", "Bearer #{token}"}]
    else
      []
    end
  end
end
