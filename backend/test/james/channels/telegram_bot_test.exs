defmodule James.Channels.TelegramBotTest do
  use James.DataCase, async: false

  alias James.Channels.TelegramBot

  @token "test-bot-token"

  setup do
    original_token = Application.get_env(:james, :telegram_bot_token)
    Application.put_env(:james, :telegram_bot_token, @token)

    on_exit(fn ->
      case original_token do
        nil -> Application.delete_env(:james, :telegram_bot_token)
        v -> Application.put_env(:james, :telegram_bot_token, v)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1" do
    test "starts as a GenServer and is alive" do
      {:ok, pid} = TelegramBot.start_link(name: nil)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "initial state contains an empty thread-to-session map" do
      {:ok, pid} = TelegramBot.start_link(name: nil)
      state = :sys.get_state(pid)
      assert is_map(state.sessions)
      assert map_size(state.sessions) == 0
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_update/2
  # ---------------------------------------------------------------------------

  describe "handle_update/2" do
    test "returns :ok for a well-formed text update" do
      update = %{
        "update_id" => 1,
        "message" => %{
          "message_id" => 10,
          "chat" => %{"id" => 1_001},
          "text" => "hello",
          "from" => %{"id" => 42}
        }
      }

      assert :ok = TelegramBot.handle_update(update, token: @token)
    end

    test "returns :ok for an update with no message key (ignores gracefully)" do
      update = %{"update_id" => 2}
      assert :ok = TelegramBot.handle_update(update, token: @token)
    end

    test "extracts chat_id and text from update" do
      chat_id = 2_001

      update = %{
        "update_id" => 3,
        "message" => %{
          "message_id" => 11,
          "chat" => %{"id" => chat_id},
          "text" => "extracted text",
          "from" => %{"id" => 77}
        }
      }

      assert :ok = TelegramBot.handle_update(update, token: @token)
    end

    test "handles update with nil text gracefully" do
      update = %{
        "update_id" => 4,
        "message" => %{
          "message_id" => 12,
          "chat" => %{"id" => 3_001},
          "from" => %{"id" => 55}
        }
      }

      assert :ok = TelegramBot.handle_update(update, token: @token)
    end
  end

  # ---------------------------------------------------------------------------
  # send_response/3 — mocked via Bypass
  # ---------------------------------------------------------------------------

  describe "send_response/3" do
    setup do
      bypass = Bypass.open()
      base = "http://localhost:#{bypass.port}"
      {:ok, bypass: bypass, base: base}
    end

    test "POSTs sendMessage to Telegram API with correct params", %{bypass: bypass, base: base} do
      chat_id = 9_001
      text = "Hello from bot"

      Bypass.expect_once(bypass, "POST", "/bot#{@token}/sendMessage", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == chat_id
        assert decoded["text"] == text

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end)

      assert :ok = TelegramBot.send_response(chat_id, text, token: @token, base_url: base)
    end

    test "returns {:error, reason} when Telegram API returns non-200", %{
      bypass: bypass,
      base: base
    } do
      Bypass.expect_once(bypass, "POST", "/bot#{@token}/sendMessage", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"ok" => false, "description" => "Bad"}))
      end)

      assert {:error, _} = TelegramBot.send_response(1_002, "hi", token: @token, base_url: base)
    end
  end

  # ---------------------------------------------------------------------------
  # start_polling/0 and stop_polling/0
  # ---------------------------------------------------------------------------

  describe "polling control" do
    test "start_polling/0 returns :ok" do
      {:ok, pid} = TelegramBot.start_link(name: nil)
      assert :ok = TelegramBot.start_polling(pid)
      GenServer.stop(pid)
    end

    test "stop_polling/0 returns :ok" do
      {:ok, pid} = TelegramBot.start_link(name: nil)
      TelegramBot.start_polling(pid)
      assert :ok = TelegramBot.stop_polling(pid)
      GenServer.stop(pid)
    end

    test "polling state is :running after start_polling" do
      {:ok, pid} = TelegramBot.start_link(name: nil)
      TelegramBot.start_polling(pid)
      state = :sys.get_state(pid)
      assert state.polling == :running
      GenServer.stop(pid)
    end

    test "polling state is :stopped after stop_polling" do
      {:ok, pid} = TelegramBot.start_link(name: nil)
      TelegramBot.start_polling(pid)
      TelegramBot.stop_polling(pid)
      state = :sys.get_state(pid)
      assert state.polling == :stopped
      GenServer.stop(pid)
    end
  end
end
