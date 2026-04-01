defmodule James.Browser.CdpTransport do
  @moduledoc """
  Default CDP WebSocket transport.

  This module is a thin wrapper around the platform WebSocket connection.
  In production it would use a proper WebSocket client library.  For now it
  returns `{:error, :not_implemented}` so that the rest of the system
  compiles and is testable without a real Chrome instance.

  Tests inject their own transport module via the `:transport` option on
  `CdpClient.start_link/1`.
  """

  @doc """
  Connect to the given WebSocket `url`.

  The `owner` PID will receive `{:cdp_frame, binary}` messages for every
  incoming WebSocket frame.

  Returns `{:ok, conn}` or `{:error, reason}`.
  """
  @spec connect(String.t(), pid()) :: {:ok, term()} | {:error, term()}
  def connect(_url, _owner) do
    {:error, :not_implemented}
  end

  @doc """
  Send a text `frame` over the WebSocket connection.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec send_frame(term(), binary()) :: :ok | {:error, term()}
  def send_frame(_conn, _frame) do
    {:error, :not_implemented}
  end
end
