defmodule James.MCP.Transports.SSE do
  @moduledoc """
  SSE (Server-Sent Events) transport for MCP servers.

  Uses Mint to connect to an SSE endpoint and parses data: lines
  as JSON-RPC messages.
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
    headers = [{"accept", "text/event-stream"} | Keyword.get(env, :headers, [])]

    case HTTP.connect(:https, parse_host(url), 443, mode: :active, log: false) do
      {:ok, conn} ->
        {:ok, request_ref} = HTTP.request(conn, "GET", parse_path(url), headers, "")

        state = %{
          conn: conn,
          request_ref: request_ref,
          url: url,
          buffer: %{}
        }

        {:ok, state, {:continue, :await_response}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:await_response, state) do
    # The Mint HTTP module will send us messages; wait for them
    {:noreply, state}
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
        Logger.error("MCP SSE stream error", reason: inspect(reason))
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_call({:send_and_receive, encoded}, _from, state) do
    # SSE is typically request-response over HTTP POST
    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    case HTTP.request(state.conn, "POST", parse_path(state.url), headers, encoded) do
      {:ok, conn, request_ref} ->
        new_state = %{state | conn: conn, request_ref: request_ref}
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
      {:status, _request_ref, _status} ->
        handle_events(rest, state)

      {:headers, _request_ref, _headers} ->
        handle_events(rest, state)

      {:data, _request_ref, data} ->
        # Parse SSE data: lines
        parse_sse_data(data)
        handle_events(rest, state)

      {:done, _request_ref} ->
        {:noreply, state}

      other ->
        Logger.debug("MCP SSE unhandled event", inspect(other))
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

            case find_response(events) do
              {:ok, data} -> {:reply, {:ok, data}, new_state}
              :none -> wait_for_response(new_state)
            end

          {:error, conn, reason} ->
            {:reply, {:error, reason}, state}
        end
    after
      @timeout ->
        {:reply, {:error, :timeout}, state}
    end
  end

  defp find_response(events) do
    Enum.find_value(events, :none, fn
      {:data, _ref, data} -> {:ok, data}
      _ -> false
    end)
  end

  defp parse_sse_data(data) do
    data
    |> String.split("\n")
    |> Enum.filter(fn line -> String.starts_with?(line, "data: ") end)
    |> Enum.map(fn line -> String.trim(line, "data: ") end)
  end

  defp parse_host(url) do
    uri = URI.parse(url)
    uri.host || "localhost"
  end

  defp parse_path(url) do
    uri = URI.parse(url)
    uri.path || "/"
  end
end
