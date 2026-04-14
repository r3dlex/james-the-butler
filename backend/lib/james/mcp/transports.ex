defmodule James.MCP.Transports do
  @moduledoc """
  Unified transport interface for MCP communication.
  Dispatches to the appropriate transport implementation.
  """

  @doc "Send a JSON-RPC message and receive a response."
  @spec send_and_receive(pid() | map(), String.t()) :: {:ok, String.t()} | {:error, term}
  def send_and_receive(pid, encoded) when is_pid(pid) do
    GenServer.call(pid, {:send_and_receive, encoded}, 30_000)
  end

  @doc "Stop a transport process."
  @spec stop(pid) :: :ok
  def stop(pid) when is_pid(pid) do
    GenServer.stop(pid, :normal)
  end

  def stop(_), do: :ok
end
