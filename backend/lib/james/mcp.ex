defmodule James.MCP do
  @moduledoc "Context module for MCP server CRUD operations."

  import Ecto.Query
  alias James.Repo
  alias James.MCP.Server

  def list_servers(user_id) do
    from(s in Server, where: s.user_id == ^user_id, order_by: [asc: s.name])
    |> Repo.all()
  end

  def get_server(id), do: Repo.get(Server, id)

  def get_server!(id), do: Repo.get!(Server, id)

  def create_server(attrs) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  def update_server_tools(server_id, tools) when is_list(tools) do
    server = get_server(server_id)
    update_server(server, %{tools: tools, status: "running"})
  end

  def get_server_with_defaults(%__MODULE__.Server{} = server) do
    %{server | tools: server.tools || [], params: server.params || %{}}
  end

  def update_server_status(server_id, status) do
    server = get_server(server_id)
    update_server(server, %{status: status})
  end

  def delete_server(%Server{} = server), do: Repo.delete(server)
end
