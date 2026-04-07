defmodule JamesWeb.McpServerController do
  use Phoenix.Controller, formats: [:json]

  alias James.MCP
  alias James.MCP.Server
  alias James.MCP.Supervisor, as: McpSupervisor

  def index(conn, _params) do
    user = conn.assigns.current_user
    servers = MCP.list_servers(user.id)
    json(conn, %{mcpServers: Enum.map(servers, &server_json/1)})
  end

  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "user_id", user.id)

    case MCP.create_server(attrs) do
      {:ok, server} ->
        conn |> put_status(:created) |> json(%{mcpServer: server_json(server)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case MCP.get_server(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      server when server.user_id != user.id ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      server ->
        # Stop the server process if running
        McpSupervisor.stop_server(server.id)
        {:ok, _} = MCP.delete_server(server)
        json(conn, %{ok: true})
    end
  end

  def start(conn, %{"id" => id}) do
    case MCP.get_server(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      server ->
        case McpSupervisor.start_server(server) do
          {:ok, _pid} ->
            {:ok, updated} = MCP.update_server(server, %{status: "running"})
            json(conn, %{mcpServer: server_json(updated)})

          {:error, reason} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
        end
    end
  end

  def stop(conn, %{"id" => id}) do
    case MCP.get_server(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      server ->
        McpSupervisor.stop_server(server.id)
        {:ok, updated} = MCP.update_server(server, %{status: "stopped"})
        json(conn, %{mcpServer: server_json(updated)})
    end
  end

  defp server_json(s) do
    %{
      id: s.id,
      name: s.name,
      transport: s.transport,
      command: s.command,
      url: s.url,
      params: s.params || %{},
      tools: s.tools || [],
      status: s.status || "stopped",
      isPreConfigured: false,
      inserted_at: s.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
