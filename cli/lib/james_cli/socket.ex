defmodule JamesCli.Socket do
  @moduledoc """
  Phoenix Channels WebSocket client using mint_web_socket.

  Handles:
  - Connection to ws://host:socket/websocket?token=<jwt>
  - Join topic "session:<session_id>"
  - Push "message:send" events
  - Receive "message:chunk", "message:end", "message:error" broadcasts
  """

  use GenServer

  @timeout 10_000

  @doc "Starts the socket connection for a session."
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Sends a message to the session."
  def send_message(pid, content) do
    GenServer.cast(pid, {:send_message, content})
  end

  @doc "Stops the socket connection."
  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  @impl true
  def init(opts) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)
    token = Keyword.fetch!(opts, :token)
    session_id = Keyword.fetch!(opts, :session_id)
    handler = Keyword.fetch!(opts, :handler)

    state = %{
      host: host,
      port: port,
      token: token,
      session_id: session_id,
      handler: handler,
      http_conn: nil,
      ws: nil,
      ref: nil,
      joined: false
    }

    case do_connect(host, port, token, session_id) do
      {:ok, http_conn, ws, ref} ->
        {:ok, %{state | http_conn: http_conn, ws: ws, ref: ref}}

      {:error, reason} ->
        {:stop, {:connection_failed, reason}}
    end
  end

  defp do_connect(host, port, token, session_id) do
    path = "/socket/websocket?token=#{token}"

    with {:ok, http_conn} <- Mint.HTTP.connect(:http, host, port, protocols: [:http1]),
         {:ok, http_conn, ref} <- Mint.WebSocket.upgrade(:ws, http_conn, path, []) do
      receive do
        {:tcp, _host, _port, data} ->
          handle_upgrade_response(http_conn, ref, data, session_id)

        {:tcp, http_conn, data} ->
          handle_upgrade_response(http_conn, ref, data, session_id)
      after
        @timeout -> {:error, :upgrade_timeout}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_upgrade_response(http_conn, ref, data, session_id) do
    http_conn = Mint.HTTP.set_mode(http_conn, :active)

    case Mint.HTTP.stream(http_conn, data) do
      {:ok, http_conn, messages} ->
        process_upgrade_messages(http_conn, ref, messages, session_id)

      _ ->
        receive do
          {:tcp, _, more_data} ->
            {:ok, http_conn, messages} = Mint.HTTP.stream(http_conn, more_data)
            process_upgrade_messages(http_conn, ref, messages, session_id)
        after
          @timeout -> {:error, :upgrade_timeout}
        end
    end
  end

  defp process_upgrade_messages(http_conn, ref, messages, session_id) do
    status = find_status(messages, ref)
    headers = find_headers(messages, ref)

    case status do
      101 ->
        {:ok, http_conn, ws} = Mint.WebSocket.new(http_conn, ref, 101, headers)
        send_join(http_conn, ws, session_id)

      _ ->
        {:error, {:bad_status, status}}
    end
  end

  defp find_status(messages, ref) do
    Enum.find_value(messages, fn
      {:status, ^ref, s} when is_integer(s) -> s
      _ -> nil
    end) || 0
  end

  defp find_headers(messages, ref) do
    Enum.find_value(messages, fn
      {:headers, ^ref, h} -> h
      _ -> nil
    end) || []
  end

  defp send_join(http_conn, ws, session_id) do
    join_payload = Phoenix.Channel.join("session:#{session_id}", %{}, %{})
    send_ws(http_conn, ws, join_payload)
  end

  @impl true
  def handle_cast({:send_message, content}, %{http_conn: http_conn, ws: ws} = state) do
    push_payload = Phoenix.Channel.push("message:send", %{"content" => content}, %{})
    {_http_conn, ws} = send_ws(http_conn, ws, push_payload)
    {:noreply, %{state | ws: ws}}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp, http_conn, data}, %{http_conn: http_conn} = state) do
    handle_data(http_conn, data, state)
  end

  def handle_info({:ssl, http_conn, data}, %{http_conn: http_conn} = state) do
    handle_data(http_conn, data, state)
  end

  @impl true
  def terminate(_reason, %{http_conn: http_conn}) do
    if http_conn, do: Mint.HTTP.close(http_conn)
    :ok
  end

  defp handle_data(http_conn, data, %{handler: handler, ws: ws} = state) do
    case Mint.HTTP.stream(http_conn, data) do
      {:ok, http_conn, messages} ->
        state = %{state | http_conn: http_conn}
        handle_http_messages(messages, http_conn, ws, handler, state)

      {:error, http_conn, reason, _resp} ->
        IO.puts(:stderr, "HTTP stream error: #{inspect(reason)}")
        {:noreply, %{state | http_conn: http_conn}}

      :unknown ->
        {:noreply, state}
    end
  end

  defp handle_http_messages([], http_conn, ws, _handler, state) do
    {:noreply, %{state | http_conn: http_conn, ws: ws}}
  end

  defp handle_http_messages([message | rest], http_conn, ws, handler, state) do
    case message do
      {:data, _ref, data} ->
        case Mint.WebSocket.decode(ws, data) do
          {:ok, ws, frames} ->
            state = %{state | http_conn: http_conn, ws: ws}
            handle_ws_frames(frames, state, handler)

          {:error, ws, reason} ->
            IO.puts(:stderr, "WebSocket decode error: #{inspect(reason)}")
            {:noreply, %{state | http_conn: http_conn, ws: ws}}
        end

      {:done, _ref} ->
        handle_http_messages(rest, http_conn, ws, handler, state)

      _ ->
        handle_http_messages(rest, http_conn, ws, handler, state)
    end
  end

  defp handle_ws_frames([], state, _handler), do: {:noreply, state}

  defp handle_ws_frames([frame | rest], state, handler) do
    case frame do
      {:text, data} ->
        case Jason.decode(data) do
          {:ok, %{"event" => "message:chunk", "payload" => %{"chunk" => chunk}}} ->
            handler.on_chunk(chunk)
            handle_ws_frames(rest, state, handler)

          {:ok, %{"event" => "message:end", "payload" => %{"content" => content}}} ->
            handler.on_end(content)
            handle_ws_frames(rest, state, handler)

          {:ok, %{"event" => "message:error", "payload" => %{"error" => error}}} ->
            handler.on_error(error)
            handle_ws_frames(rest, state, handler)

          {:ok, %{"event" => "phx_reply", "payload" => %{"status" => "ok"}}} ->
            handle_ws_frames(rest, %{state | joined: true}, handler)

          {:ok,
           %{"event" => "phx_reply", "payload" => %{"status" => "error", "reason" => reason}}} ->
            handler.on_error("Join failed: #{reason}")
            handle_ws_frames(rest, state, handler)

          _ ->
            handle_ws_frames(rest, state, handler)
        end

      :pong ->
        handle_ws_frames(rest, state, handler)

      _ ->
        handle_ws_frames(rest, state, handler)
    end
  end

  defp send_ws(http_conn, ws, payload) do
    {:ok, ws, encoded} = Mint.WebSocket.encode(ws, {:text, Jason.encode!(payload)})
    {:ok, http_conn} = Mint.HTTP.stream_request_body(http_conn, ws, encoded)
    {http_conn, ws}
  end
end

defmodule Phoenix.Channel do
  @moduledoc false

  def join(topic, payload, _auth \\ %{}) do
    %{
      "event" => "phx_join",
      "topic" => topic,
      "payload" => payload,
      "ref" => nil
    }
  end

  def push(event, payload, topic) do
    %{
      "event" => event,
      "topic" => topic,
      "payload" => payload,
      "ref" => nil
    }
  end
end
