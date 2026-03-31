defmodule James.Desktop.Daemon do
  @moduledoc """
  Communication layer with the native desktop daemon.
  The daemon handles screen capture and input simulation via platform-specific APIs.
  This is a stub — the actual daemon is a separate native process.
  """

  require Logger

  @doc "Check if the daemon process is running and connected."
  def status do
    # In production, this would check a Unix socket or TCP connection
    :disconnected
  end

  @doc "Execute a desktop action through the daemon."
  def execute(action, params \\ %{}) do
    if status() == :connected do
      send_command(action, params)
    else
      "Desktop daemon is not running. Start it with: james-daemon start"
    end
  end

  defp send_command(action, params) do
    Logger.info("Desktop daemon: #{action} with #{inspect(params)}")
    # Would send via Unix socket / gRPC to the native daemon
    "Action '#{action}' executed."
  end
end
