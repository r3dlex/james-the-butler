defmodule James.MCP.Server.GenServer do
  @moduledoc """
  GenServer that manages the lifecycle of a single MCP server process.

  Handles stdio (Port), SSE (Mint), and streamable_http transports.
  Maintains tool list cache and dispatches tool calls to the remote server.
  """

  use GenServer
  require Logger

  alias James.MCP.{Client, Transports}
  alias James.Agents.Tools.Registry, as: ToolsRegistry

  @registry James.MCP.Server.Registry

  def start_link(%James.MCP.Server{} = server) do
    name = {:via, Registry, {@registry, server.id}}
    GenServer.start_link(__MODULE__, server, name: name)
  end

  @impl true
  def init(%James.MCP.Server{} = server) do
    state = %{
      server: server,
      transport_pid: nil,
      tools: []
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case connect_transport(state.server) do
      {:ok, transport_state} ->
        {:ok, tools} = fetch_and_register_tools(state.server.id, transport_state)
        {:noreply, %{state | transport_pid: transport_state, tools: tools}}

      {:error, reason} ->
        Logger.error("MCP server connection failed",
          server_id: state.server.id,
          reason: inspect(reason)
        )

        James.MCP.update_server_status(state.server.id, "error")
        {:stop, {:shutdown, reason}, state}
    end
  end

  # --- Client calls ---

  def call_tool(server_id, tool_name, arguments) do
    GenServer.call(via(server_id), {:call_tool, tool_name, arguments})
  end

  def list_tools(server_id) do
    GenServer.call(via(server_id), :list_tools)
  end

  def restart(server_id) do
    GenServer.cast(via(server_id), :restart)
  end

  # --- Callbacks ---

  @impl true
  def handle_call({:call_tool, tool_name, arguments}, _from, state) do
    reply =
      with {:ok, transport_state} <- get_transport(state),
           {:ok, result} <- Client.call_tool(transport_state, tool_name, arguments) do
        {:ok, result}
      else
        {:error, reason} -> {:error, reason}
        :no_transport -> {:error, :no_transport}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    {:reply, state.tools, state}
  end

  @impl true
  def handle_cast(:restart, state) do
    Logger.info("MCP server restarting", server_id: state.server.id)
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("MCP server terminating", server_id: state.server.id, reason: inspect(reason))
    Transports.stop(state.transport_pid)
    :ok
  end

  # --- Private ---

  defp via(server_id) do
    {:via, Registry, {@registry, server_id}}
  end

  defp connect_transport(server) do
    case server.transport do
      "stdio" -> Transports.STDIO.start_link(server)
      "sse" -> Transports.SSE.start_link(server)
      "streamable_http" -> Transports.StreamableHTTP.start_link(server)
    end
  end

  defp get_transport(%{transport_pid: nil}), do: :no_transport
  defp get_transport(%{transport_pid: pid}), do: {:ok, pid}

  defp fetch_and_register_tools(server_id, transport_state) do
    case Client.list_tools(transport_state) do
      {:ok, tools} when is_list(tools) ->
        mcp_tools =
          Enum.map(tools, fn tool ->
            tool_name = "mcp__#{server_id}__#{tool["name"]}"

            definition = %{
              name: tool_name,
              description: tool["description"],
              input_schema: tool["inputSchema"] || %{}
            }

            ToolsRegistry.register(definition)
            definition
          end)

        James.MCP.update_server_tools(server_id, mcp_tools)
        {:ok, mcp_tools}

      other ->
        Logger.warning("Failed to fetch MCP tools", server_id: server_id, result: inspect(other))
        {:ok, []}
    end
  end
end
