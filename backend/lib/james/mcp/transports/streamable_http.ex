defmodule James.MCP.Transports.StreamableHTTP do
  @moduledoc """
  Streamable HTTP transport for MCP servers.

  Uses Mint to connect to an HTTP endpoint with chunked transfer encoding.
  Similar to SSE but handles streaming HTTP responses.
  """

  use GenServer
  require Logger

  alias Mint.HTTP

  @timeout 30_000

  def start_link(%James.MCP.Server{} = server) do
    GenServer.start_link(__MODULE__, server)
  end

  @impl true
  def init(%James.MCP.Server{url: url, env: env}) do
    headers = [
      {"accept", "application/json"},
      {"content-type", "application/json"}
    ]

    uri = URI.parse(url)
    host = uri.host || "localhost"
    port = uri.port || 443
    path = uri.path || "/"
    scheme = if port == 443, do: :https, else: :http

    case HTTP.connect(scheme, host, port, mode: :active, log: false) do
      {:ok, conn} ->
        {:ok, _request_ref} = HTTP.request(conn, "POST", path, headers, "{}")

        state = %{
          conn: conn,
          url: url,
          request_ref: nil,
          buffer: <<>>
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(message, state) do
    case HTTP.stream(state.conn, message) do
      :unknown ->
        {:noreply, state}

      {:ok, conn, events} ->
        new_state = %{state | conn: conn}
        handle_events(events, new_state)

      {:error, conn, reason} ->
        Logger.error("MCP HTTP stream error", reason: inspect(reason))
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_call({:send_and_receive, encoded}, _from, state) do
    uri = URI.parse(state.url)
    path = uri.path || "/"

    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    case HTTP.request(state.conn, "POST", path, headers, encoded) do
      {:ok, conn, _request_ref} ->
        new_state = %{state | conn: conn}
        wait_for_response(new_state)

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.conn, do: HTTP.close(state.conn)
    :ok
  end

  # --- Callbacks for send_and_receive ---

  def send_and_receive(pid, encoded) when is_pid(pid) do
    GenServer.call(pid, {:send_and_receive, encoded}, @timeout)
  end

  def stop(pid) when is_pid(pid) do
    GenServer.stop(pid, :normal)
  end

  # --- Private ---

  defp handle_events([], state), do: {:noreply, state}

  defp handle_events([event | rest], state) do
    case event do
      {:status, _ref, _status} ->
        handle_events(rest, state)

      {:headers, _ref, _headers} ->
        handle_events(rest, state)

      {:data, _ref, data} ->
        # Accumulate chunked data
        new_buffer = state.buffer <> data
        handle_events(rest, %{state | buffer: new_buffer})

      {:done, _ref} ->
        # Response complete, send buffer to waiting caller
        {:noreply, state}

      other ->
        Logger.debug("MCP HTTP unhandled event", inspect(other))
        handle_events(rest, state)
    end
  end

  defp wait_for_response(state) do
    receive do
      message ->
        case HTTP.stream(state.conn, message) do
          :unknown ->
            wait_for_response(state)

          {:ok, conn, events} ->
            new_state = %{state | conn: conn}

            case process_response_events(events, new_state) do
              {:ok, data} -> {:reply, {:ok, data}, new_state}
              :continue -> wait_for_response(new_state)
            end

          {:error, _conn, reason} ->
            {:reply, {:error, reason}, state}
        end
    after
      @timeout ->
        {:reply, {:error, :timeout}, state}
    end
  end

  defp process_response_events([], _state), do: :continue

  defp process_response_events([event | rest], state) do
    case event do
      {:status, _ref, _status} ->
        process_response_events(rest, state)

      {:headers, _ref, _headers} ->
        process_response_events(rest, state)

      {:data, _ref, data} ->
        {:ok, data}

      {:done, _ref} ->
        {:ok, state.buffer}

      _ ->
        process_response_events(rest, state)
    end
  end
end
