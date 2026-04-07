defmodule James.MCP.Transports.STDIO do
  @moduledoc """
  STDIO transport for MCP servers.

  Spawns the MCP server as a Port process and communicates via
  JSON-RPC messages on stdin/stdout using line-based framing.
  """

  use GenServer
  require Logger

  @timeout 30_000

  # --- API ---

  def start_link(%James.MCP.Server{} = server) do
    GenServer.start_link(__MODULE__, server)
  end

  @doc "Send a JSON-RPC message and wait for the line-delimited response."
  def send_and_receive(pid, encoded) when is_pid(pid) do
    GenServer.call(pid, {:send_and_receive, encoded}, @timeout)
  end

  def stop(pid) when is_pid(pid) do
    GenServer.stop(pid, :normal)
  end

  # --- Callbacks ---

  @impl true
  def init(%James.MCP.Server{command: command, env: env}) do
    env_list = build_env(env)

    port =
      Port.open({:spawn, command}, [
        :stream,
        :binary,
        :exit_status,
        {:env, env_list}
      ])

    state = %{port: port, pending_from: nil, buffer: <<>>}
    {:ok, state}
  end

  @impl true
  def handle_call({:send_and_receive, encoded}, from, %{pending_from: nil} = state) do
    # Send JSON-RPC message with newline delimiter
    send(state.port, {self(), {:command, encoded <> "\n"}})

    # Store caller and wait for response
    {:noreply, %{state | pending_from: from}}
  end

  @impl true
  def handle_call({:send_and_receive, _}, _from, %{pending_from: existing} = state) do
    # Already have a pending request — reject concurrent calls
    {:reply, {:error, :busy}, state}
  end

  @impl true
  def handle_info({port, {:data, <<data::binary>>}}, %{port: port} = state)
      when port == state.port do
    new_buffer = <<state.buffer::binary, data::binary>>

    case consume_line(new_buffer) do
      {:line, line, remainder} ->
        # Reply to waiting caller
        from = state.pending_from
        new_state = %{state | buffer: remainder, pending_from: nil}
        GenServer.reply(from, {:ok, line})
        {:noreply, new_state}

      :incomplete ->
        {:noreply, %{state | buffer: new_buffer}}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state)
      when port == state.port do
    Logger.info("MCP stdio process exited", status: status)
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    if is_port(state.port), do: Port.close(state.port)
    :ok
  end

  # --- Private ---

  defp build_env(env) when is_map(env) do
    System.get_env()
    |> Map.merge(env)
    |> Enum.to_list()
  end

  defp build_env(_), do: []

  # Consume a complete line (ending in \n) from the buffer
  defp consume_line(<<>>) do
    :incomplete
  end

  defp consume_line(buffer) do
    case :binary.match(buffer, "\n") do
      :nomatch ->
        :incomplete

      pos ->
        <<line::binary-size(pos), "\n", remainder::binary>> = buffer
        {:line, line, remainder}
    end
  end
end
