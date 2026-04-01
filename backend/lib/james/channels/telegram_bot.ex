defmodule James.Channels.TelegramBot do
  @moduledoc """
  GenServer that polls the Telegram Bot API for updates, routes incoming text
  messages to the appropriate session via `James.Channels.Telegram`, and sends
  responses back to the originating chat.

  ## Configuration

  The bot API token is read from `Application.get_env(:james, :telegram_bot_token)`.

  ## Polling

  Long-polling is scheduled via `Process.send_after/3`. Call `start_polling/1`
  to begin the polling loop and `stop_polling/1` to stop it. While polling is
  stopped the GenServer remains alive and its session-mapping state is retained.

  ## Sending responses

  `send_response/3` issues a `POST /bot<token>/sendMessage` to the Telegram API.
  Pass `base_url:` and `token:` options to override defaults (useful in tests).
  """

  use GenServer

  require Logger

  @default_base_url "https://api.telegram.org"
  @poll_interval_ms 1_000

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Starts the polling loop on the given bot process (defaults to the named
  process `TelegramBot`).
  """
  def start_polling(server \\ __MODULE__) do
    GenServer.call(server, :start_polling)
  end

  @doc """
  Stops the polling loop. The GenServer process remains alive.
  """
  def stop_polling(server \\ __MODULE__) do
    GenServer.call(server, :stop_polling)
  end

  @doc """
  Parses a Telegram update map, extracts the message text and chat ID, and
  routes the message to the appropriate session.

  Returns `:ok` regardless of routing outcome so callers do not need to handle
  partial failures (errors are logged).

  Options:
    - `:token` — bot token override (default: application config)
    - `:base_url` — Telegram API base URL override (default: https://api.telegram.org)
  """
  def handle_update(update, opts \\ []) do
    case get_in(update, ["message"]) do
      nil ->
        :ok

      message ->
        chat_id = get_in(message, ["chat", "id"])
        text = Map.get(message, "text")

        if chat_id && text do
          do_route_message(chat_id, text, opts)
        else
          :ok
        end
    end
  end

  @doc """
  Sends a text response to the given `chat_id` via the Telegram `sendMessage`
  endpoint.

  Options:
    - `:token` — bot token (default: application config)
    - `:base_url` — Telegram API base URL (default: https://api.telegram.org)

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def send_response(chat_id, text, opts \\ []) do
    token = Keyword.get(opts, :token, Application.get_env(:james, :telegram_bot_token))
    base_url = Keyword.get(opts, :base_url, @default_base_url)
    url = "#{base_url}/bot#{token}/sendMessage"

    case Req.post(url, json: %{chat_id: chat_id, text: text}) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Telegram API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    {:ok, %{sessions: %{}, polling: :stopped, offset: 0}}
  end

  @impl true
  def handle_call(:start_polling, _from, state) do
    schedule_poll()
    {:reply, :ok, %{state | polling: :running}}
  end

  @impl true
  def handle_call(:stop_polling, _from, state) do
    {:reply, :ok, %{state | polling: :stopped}}
  end

  @impl true
  def handle_info(:poll, %{polling: :stopped} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = do_poll(state)
    schedule_poll()
    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end

  defp do_poll(state) do
    token = Application.get_env(:james, :telegram_bot_token)
    base_url = @default_base_url

    if is_nil(token) do
      state
    else
      url = "#{base_url}/bot#{token}/getUpdates"
      params = %{offset: state.offset, timeout: 0}

      case Req.get(url, params: params) do
        {:ok, %{status: 200, body: %{"ok" => true, "result" => updates}}} ->
          process_updates(updates, state)

        {:ok, response} ->
          Logger.warning("TelegramBot poll unexpected response: #{inspect(response)}")
          state

        {:error, reason} ->
          Logger.warning("TelegramBot poll error: #{inspect(reason)}")
          state
      end
    end
  end

  defp process_updates([], state), do: state

  defp process_updates(updates, state) do
    new_offset =
      updates
      |> Enum.map(fn u ->
        handle_update(u)
        Map.get(u, "update_id", 0)
      end)
      |> Enum.max()

    %{state | offset: new_offset + 1}
  end

  defp do_route_message(chat_id, text, _opts) do
    alias James.Channels.Telegram

    case Telegram.handle_message(chat_id, text) do
      {:ok, _session_id} ->
        :ok

      {:error, reason} ->
        Logger.debug("TelegramBot route message error for chat #{chat_id}: #{inspect(reason)}")
        :ok
    end
  end
end
