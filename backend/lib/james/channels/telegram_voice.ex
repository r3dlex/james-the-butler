defmodule James.Channels.TelegramVoice do
  @moduledoc """
  Voice message handling for the Telegram channel.

  Provides three public functions:

    * `download_voice/2` — retrieves a voice file from the Telegram Bot API
      using the two-step `getFile` + file-download flow.

    * `transcribe/2` — submits raw audio bytes to the OpenAI Whisper API
      (`/v1/audio/transcriptions`) and returns the transcribed text.

    * `process_voice_message/2` — orchestrates the full pipeline:
      download → transcribe, returning `{:ok, text}` or `{:error, reason}`.

  ## Configuration

    * Telegram bot token: `Application.get_env(:james, :telegram_bot_token)`
    * OpenAI API key: `Application.get_env(:james, :openai_api_key)` or
      `OPENAI_API_KEY` environment variable.

  Both functions accept keyword overrides (`token:`, `base_url:`,
  `openai_base_url:`) so that tests can inject Bypass endpoints.
  """

  require Logger

  @default_telegram_base "https://api.telegram.org"
  @default_openai_base "https://api.openai.com"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Downloads a Telegram voice file identified by `file_id`.

  Steps:
    1. `GET /bot<token>/getFile?file_id=<file_id>` — resolves the `file_path`.
    2. `GET /file/bot<token>/<file_path>` — downloads the raw audio bytes.

  Options:
    - `:token` — bot token override (default: application config)
    - `:base_url` — Telegram API base URL override

  Returns `{:ok, binary}` or `{:error, reason}`.
  """
  def download_voice(file_id, opts \\ []) do
    token = Keyword.get(opts, :token, Application.get_env(:james, :telegram_bot_token))
    base_url = Keyword.get(opts, :base_url, @default_telegram_base)

    case get_file_path(file_id, token, base_url) do
      {:ok, file_path} -> download_file(file_path, token, base_url)
      error -> error
    end
  end

  @doc """
  Transcribes raw audio bytes via the OpenAI Whisper API.

  Sends a `multipart/form-data` POST to `/v1/audio/transcriptions` with the
  audio data as `file` and `"whisper-1"` as the model.

  Options:
    - `:openai_base_url` — OpenAI API base URL override (default: https://api.openai.com)

  Returns `{:ok, text}` or `{:error, reason}`.
  """
  def transcribe(audio_data, opts \\ []) do
    api_key =
      Application.get_env(:james, :openai_api_key) || System.get_env("OPENAI_API_KEY")

    base_url = Keyword.get(opts, :openai_base_url, @default_openai_base)
    url = "#{base_url}/v1/audio/transcriptions"

    form_fields = [
      {"file", {audio_data, filename: "voice.ogg", content_type: "audio/ogg"}},
      {"model", "whisper-1"}
    ]

    case Req.post(url,
           form_multipart: form_fields,
           headers: [{"authorization", "Bearer #{api_key}"}]
         ) do
      {:ok, %{status: 200, body: %{"text" => text}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        {:error, "Whisper API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Full voice message pipeline: download from Telegram then transcribe via Whisper.

  Options:
    - `:token` — bot token override
    - `:base_url` — Telegram API base URL override
    - `:openai_base_url` — OpenAI API base URL override

  Returns `{:ok, transcribed_text}` or `{:error, reason}`.
  """
  def process_voice_message(file_id, opts \\ []) do
    case download_voice(file_id, opts) do
      {:ok, audio_data} -> transcribe(audio_data, opts)
      error -> error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp get_file_path(file_id, token, base_url) do
    url = "#{base_url}/bot#{token}/getFile"

    case Req.get(url, params: %{file_id: file_id}) do
      {:ok, %{status: 200, body: %{"ok" => true, "result" => %{"file_path" => file_path}}}} ->
        {:ok, file_path}

      {:ok, %{status: status, body: body}} ->
        {:error, "Telegram getFile error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp download_file(file_path, token, base_url) do
    url = "#{base_url}/file/bot#{token}/#{file_path}"

    case Req.get(url) do
      {:ok, %{status: 200, body: data}} ->
        {:ok, data}

      {:ok, %{status: status, body: body}} ->
        {:error, "Telegram file download error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
