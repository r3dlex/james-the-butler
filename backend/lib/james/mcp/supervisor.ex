defmodule James.MCP.Supervisor do
  @moduledoc "DynamicSupervisor managing individual MCP server GenServer processes."

  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Start or reuse an MCP server GenServer for the given server config."
  @spec start_server(server :: James.MCP.Server.t()) :: :ignore | {:error, term} | {:ok, pid}
  def start_server(%James.MCP.Server{} = server) do
    case DynamicSupervisor.start_child(__MODULE__, {James.MCP.Server.GenServer, server}) do
      {:ok, pid} = ok ->
        Logger.info("MCP server started", server_id: server.id, name: server.name, pid: pid)
        ok

      {:error, {:already_started, pid}} ->
        Logger.info("MCP server already running, reusing", server_id: server.id, pid: pid)
        {:ok, pid}

      other ->
        Logger.error("Failed to start MCP server", server_id: server.id, error: inspect(other))
        other
    end
  end

  @doc "Stop an MCP server GenServer by server id."
  @spec stop_server(server_id :: Ecto.UUID.t()) :: :ok
  def stop_server(server_id) do
    case Registry.lookup(James.MCP.Server.Registry, server_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        :ok
    end
  end
end
