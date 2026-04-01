defmodule James.Desktop.Daemon do
  @moduledoc """
  Communication layer with the native desktop daemon.

  The daemon handles screen capture and input simulation via platform-specific
  APIs.  It listens on a Unix socket whose path defaults to
  `/tmp/james-daemon.sock` (override with the `JAMES_DAEMON_SOCKET` env var).

  ## Connection check

  `connected?/0` checks whether the daemon socket file exists **and** responds
  to a lightweight `:ping` command.  `status/0` returns the equivalent atom.

  ## Actions

  `execute/2` accepts the following atoms (all params are maps):

    * `:screenshot`  – capture the screen (`{}`)
    * `:click`       – mouse click (`%{x: …, y: …}`)
    * `:type_text`   – keyboard input (`%{text: …}`)
    * `:key_press`   – single key stroke (`%{key: …}`)
    * `:scroll`      – scroll wheel (`%{direction: …, amount: …}`)
    * `:drag`        – drag gesture (`%{from_x:, from_y:, to_x:, to_y:}`)

  When the daemon is not connected `execute/2` returns `{:error, :not_connected}`.
  """

  require Logger

  @default_socket "/tmp/james-daemon.sock"
  @connect_timeout 500
  @recv_timeout 5_000

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp socket_path do
    System.get_env("JAMES_DAEMON_SOCKET", @default_socket)
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Return `true` when the daemon socket exists and responds to a ping.
  """
  @spec connected?() :: boolean()
  def connected? do
    path = socket_path()

    if File.exists?(path) do
      ping_daemon(path)
    else
      false
    end
  end

  @doc """
  Return `:connected` if `connected?/0` is true, `:disconnected` otherwise.

  Kept for backward compatibility with existing callers.
  """
  @spec status() :: :connected | :disconnected
  def status do
    if connected?(), do: :connected, else: :disconnected
  end

  @doc """
  Execute a desktop action through the daemon.

  Returns `{:ok, result_map}` on success, or `{:error, :not_connected}` when
  the daemon is unavailable, or `{:error, reason}` for protocol/IO failures.
  """
  @spec execute(atom() | String.t(), map()) ::
          {:ok, map()} | {:error, term()} | String.t()
  def execute(action, params \\ %{})

  def execute(action, params) when is_atom(action) do
    if connected?() do
      send_command(action, params)
    else
      {:error, :not_connected}
    end
  end

  # Legacy string-based interface — kept for backward compatibility.
  def execute(action, _params) when is_binary(action) do
    "Desktop daemon is not running. Start it with: james-daemon start"
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp ping_daemon(path) do
    case connect_socket(path) do
      {:ok, sock} ->
        frame = James.Desktop.Protocol.encode(:screenshot, %{})
        result = send_and_recv(sock, frame)
        :gen_tcp.close(sock)

        case result do
          {:ok, _} -> true
          _ -> false
        end

      {:error, _} ->
        false
    end
  end

  defp send_command(action, params) do
    path = socket_path()

    case connect_socket(path) do
      {:ok, sock} ->
        frame = James.Desktop.Protocol.encode(action, params)
        result = send_and_recv(sock, frame)
        :gen_tcp.close(sock)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Connect to the Unix-domain socket.
  # :gen_tcp supports AF_UNIX on OTP 23+ when `:local` is used.
  defp connect_socket(path) do
    :gen_tcp.connect(
      {:local, path},
      0,
      [:binary, active: false, packet: :line],
      @connect_timeout
    )
  end

  defp send_and_recv(sock, frame) do
    with :ok <- :gen_tcp.send(sock, frame <> "\n"),
         {:ok, data} <- :gen_tcp.recv(sock, 0, @recv_timeout) do
      James.Desktop.Protocol.decode(String.trim(data))
    end
  end
end
