defmodule James.Browser.CdpClient do
  @moduledoc """
  Chrome DevTools Protocol (CDP) WebSocket client.

  Manages a single CDP session using JSON-RPC 2.0 framing over a WebSocket
  connection.  The underlying transport is injected at start time so that
  tests can substitute a lightweight in-process mock without needing a real
  Chrome instance.

  ## Protocol

  Every command is sent as:

      {"id": N, "method": "Domain.method", "params": {...}}

  Every response carries the matching `id`:

      {"id": N, "result": {...}}     # success
      {"id": N, "error": {...}}      # failure

  Pending requests are stored in the GenServer state keyed by `id` so that
  each caller is unblocked exactly once when the matching response arrives.

  ## Transport contract

  The transport module must export two functions:

    * `connect(url)` → `{:ok, conn}` | `{:error, reason}`
    * `send_frame(conn, binary)` → `:ok` | `{:error, reason}`

  Incoming frames must be delivered to the owning GenServer as:

      send(pid, {:cdp_frame, binary})
  """

  use GenServer

  require Logger

  @default_transport James.Browser.CdpTransport
  @command_timeout 5_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Start a `CdpClient` linked to the calling process.

  Options:
    * `:url`       – WebSocket endpoint, e.g. `"ws://localhost:9222/devtools/page/ID"`.
    * `:transport` – Transport module (default: `#{@default_transport}`).
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Connect to the CDP WebSocket endpoint.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec connect(pid(), String.t()) :: :ok | {:error, term()}
  def connect(pid, url) do
    GenServer.call(pid, {:connect, url})
  end

  @doc """
  Send a CDP JSON-RPC command and wait for its response.

  Returns `{:ok, result_map}` or `{:error, reason}`.
  """
  @spec send_command(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def send_command(pid, method, params \\ %{}) do
    GenServer.call(pid, {:send_command, method, params}, @command_timeout)
  end

  @doc """
  Navigate the page to `url`.  Delegates to `Page.navigate`.
  """
  @spec navigate(pid(), String.t()) :: {:ok, map()} | {:error, term()}
  def navigate(pid, url) do
    send_command(pid, "Page.navigate", %{"url" => url})
  end

  @doc """
  Evaluate a JavaScript `expression` in the page context.
  Delegates to `Runtime.evaluate`.
  """
  @spec evaluate(pid(), String.t()) :: {:ok, map()} | {:error, term()}
  def evaluate(pid, expression) do
    send_command(pid, "Runtime.evaluate", %{"expression" => expression})
  end

  @doc """
  Capture a PNG screenshot of the current page.
  Returns `{:ok, %{"data" => base64_string}}` or `{:error, reason}`.
  """
  @spec screenshot(pid()) :: {:ok, map()} | {:error, term()}
  def screenshot(pid) do
    send_command(pid, "Page.captureScreenshot", %{"format" => "png"})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    transport = Keyword.get(opts, :transport, @default_transport)

    state = %{
      transport: transport,
      conn: nil,
      next_id: 1,
      pending: %{}
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:connect, url}, _from, state) do
    case state.transport.connect(url, self()) do
      {:ok, conn} ->
        {:reply, :ok, %{state | conn: conn}}

      {:error, reason} = err ->
        Logger.warning("CdpClient: connection failed: #{inspect(reason)}")
        {:reply, err, state}
    end
  end

  def handle_call({:send_command, _method, _params}, _from, %{conn: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:send_command, method, params}, from, state) do
    id = state.next_id
    frame = Jason.encode!(%{"id" => id, "method" => method, "params" => params})

    case state.transport.send_frame(state.conn, frame) do
      :ok ->
        pending = Map.put(state.pending, id, from)
        {:noreply, %{state | next_id: id + 1, pending: pending}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{state | next_id: id + 1}}
    end
  end

  @impl GenServer
  def handle_info({:cdp_frame, binary}, state) do
    {:noreply, process_frame(binary, state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp process_frame(binary, state) do
    case Jason.decode(binary) do
      {:ok, %{"id" => id} = msg} -> dispatch_response(id, msg, state)
      {:ok, _event} -> state
      {:error, reason} -> log_bad_frame(reason, state)
    end
  end

  defp dispatch_response(id, msg, state) do
    case Map.pop(state.pending, id) do
      {nil, _pending} ->
        Logger.debug("CdpClient: unexpected response id=#{id}")
        state

      {from, pending} ->
        GenServer.reply(from, build_reply(msg))
        %{state | pending: pending}
    end
  end

  defp build_reply(msg) do
    cond do
      Map.has_key?(msg, "result") -> {:ok, msg["result"]}
      Map.has_key?(msg, "error") -> {:error, msg["error"]}
      true -> {:error, :unknown_response}
    end
  end

  defp log_bad_frame(reason, state) do
    Logger.warning("CdpClient: bad JSON frame: #{inspect(reason)}")
    state
  end
end
