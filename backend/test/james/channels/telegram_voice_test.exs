defmodule James.Channels.TelegramVoiceTest do
  use ExUnit.Case, async: false

  alias James.Channels.TelegramVoice

  @token "test-voice-token"
  @openai_key "test-openai-key"

  setup do
    original_token = Application.get_env(:james, :telegram_bot_token)
    original_key = Application.get_env(:james, :openai_api_key)
    original_env_key = System.get_env("OPENAI_API_KEY")

    Application.put_env(:james, :telegram_bot_token, @token)
    Application.put_env(:james, :openai_api_key, @openai_key)

    on_exit(fn ->
      case original_token do
        nil -> Application.delete_env(:james, :telegram_bot_token)
        v -> Application.put_env(:james, :telegram_bot_token, v)
      end

      case original_key do
        nil -> Application.delete_env(:james, :openai_api_key)
        v -> Application.put_env(:james, :openai_api_key, v)
      end

      case original_env_key do
        nil -> System.delete_env("OPENAI_API_KEY")
        v -> System.put_env("OPENAI_API_KEY", v)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # download_voice/2
  # ---------------------------------------------------------------------------

  describe "download_voice/2" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass, base: "http://localhost:#{bypass.port}"}
    end

    test "fetches file info and downloads binary data", %{bypass: bypass, base: base} do
      file_id = "voice_file_001"
      file_path = "voice/file_001.ogg"
      audio_bytes = <<79, 103, 103, 83>>

      Bypass.expect_once(bypass, "GET", "/bot#{@token}/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"ok" => true, "result" => %{"file_path" => file_path}})
        )
      end)

      Bypass.expect_once(bypass, "GET", "/file/bot#{@token}/#{file_path}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/octet-stream")
        |> Plug.Conn.send_resp(200, audio_bytes)
      end)

      assert {:ok, ^audio_bytes} =
               TelegramVoice.download_voice(file_id, token: @token, base_url: base)
    end

    test "returns {:error, reason} when getFile API call fails", %{bypass: bypass, base: base} do
      Bypass.expect_once(bypass, "GET", "/bot#{@token}/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"ok" => false, "description" => "Bad file"}))
      end)

      assert {:error, _reason} =
               TelegramVoice.download_voice("bad_file_id", token: @token, base_url: base)
    end

    test "returns {:error, reason} when file download fails", %{bypass: bypass, base: base} do
      file_id = "voice_file_002"
      file_path = "voice/file_002.ogg"

      Bypass.expect_once(bypass, "GET", "/bot#{@token}/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"ok" => true, "result" => %{"file_path" => file_path}})
        )
      end)

      Bypass.expect_once(bypass, "GET", "/file/bot#{@token}/#{file_path}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "not found")
      end)

      assert {:error, _reason} =
               TelegramVoice.download_voice(file_id, token: @token, base_url: base)
    end
  end

  # ---------------------------------------------------------------------------
  # transcribe/1
  # ---------------------------------------------------------------------------

  describe "transcribe/1" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass, base: "http://localhost:#{bypass.port}"}
    end

    test "returns transcribed text on successful Whisper API call", %{bypass: bypass, base: base} do
      audio_data = <<79, 103, 103, 83, 0>>

      Bypass.expect_once(bypass, "POST", "/v1/audio/transcriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"text" => "transcribed voice content"}))
      end)

      assert {:ok, "transcribed voice content"} =
               TelegramVoice.transcribe(audio_data, openai_base_url: base)
    end

    test "returns {:error, reason} when Whisper API returns non-200", %{
      bypass: bypass,
      base: base
    } do
      Bypass.expect_once(bypass, "POST", "/v1/audio/transcriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{"error" => %{"message" => "Invalid API key"}})
        )
      end)

      assert {:error, _reason} = TelegramVoice.transcribe(<<1, 2, 3>>, openai_base_url: base)
    end

    test "returns {:error, reason} when audio data is empty", %{bypass: bypass, base: base} do
      Bypass.stub(bypass, "POST", "/v1/audio/transcriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{"error" => %{"message" => "Audio file is too short"}})
        )
      end)

      assert {:error, _reason} = TelegramVoice.transcribe(<<>>, openai_base_url: base)
    end

    test "sends multipart request with audio file to Whisper", %{bypass: bypass, base: base} do
      audio_data = <<79, 103, 103, 83, 1, 2, 3>>

      Bypass.expect_once(bypass, "POST", "/v1/audio/transcriptions", fn conn ->
        content_type = conn |> Plug.Conn.get_req_header("content-type") |> List.first()
        assert content_type =~ "multipart/form-data"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"text" => "ok"}))
      end)

      assert {:ok, _} = TelegramVoice.transcribe(audio_data, openai_base_url: base)
    end
  end

  # ---------------------------------------------------------------------------
  # process_voice_message/2
  # ---------------------------------------------------------------------------

  describe "process_voice_message/2" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass, base: "http://localhost:#{bypass.port}"}
    end

    test "full pipeline: download → transcribe → returns transcribed text", %{
      bypass: bypass,
      base: base
    } do
      file_id = "voice_pipeline_001"
      file_path = "voice/pipeline_001.ogg"
      audio_bytes = <<79, 103, 103, 83, 4>>

      Bypass.expect_once(bypass, "GET", "/bot#{@token}/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"ok" => true, "result" => %{"file_path" => file_path}})
        )
      end)

      Bypass.expect_once(bypass, "GET", "/file/bot#{@token}/#{file_path}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/octet-stream")
        |> Plug.Conn.send_resp(200, audio_bytes)
      end)

      Bypass.expect_once(bypass, "POST", "/v1/audio/transcriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"text" => "pipeline transcription"}))
      end)

      assert {:ok, "pipeline transcription"} =
               TelegramVoice.process_voice_message(file_id,
                 token: @token,
                 base_url: base,
                 openai_base_url: base
               )
    end

    test "returns {:error, reason} when download fails", %{bypass: bypass, base: base} do
      Bypass.expect_once(bypass, "GET", "/bot#{@token}/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"ok" => false}))
      end)

      assert {:error, _reason} =
               TelegramVoice.process_voice_message("bad_file",
                 token: @token,
                 base_url: base,
                 openai_base_url: base
               )
    end

    test "returns {:error, reason} when transcription fails", %{bypass: bypass, base: base} do
      file_id = "voice_pipeline_002"
      file_path = "voice/pipeline_002.ogg"

      Bypass.expect_once(bypass, "GET", "/bot#{@token}/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"ok" => true, "result" => %{"file_path" => file_path}})
        )
      end)

      Bypass.expect_once(bypass, "GET", "/file/bot#{@token}/#{file_path}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/octet-stream")
        |> Plug.Conn.send_resp(200, <<79, 103, 103, 83>>)
      end)

      Bypass.expect_once(bypass, "POST", "/v1/audio/transcriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          500,
          Jason.encode!(%{"error" => %{"message" => "Internal server error"}})
        )
      end)

      assert {:error, _reason} =
               TelegramVoice.process_voice_message(file_id,
                 token: @token,
                 base_url: base,
                 openai_base_url: base
               )
    end
  end
end
