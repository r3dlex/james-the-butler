defmodule James.Channels.TelegramTest do
  use James.DataCase

  alias James.{Accounts, Sessions}
  alias James.Channels.Telegram

  defp create_user(email \\ "telegram_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "TG Session"})
    session
  end

  describe "confirmed_timeout/0" do
    test "returns the configured timeout in seconds" do
      assert is_integer(Telegram.confirmed_timeout())
      assert Telegram.confirmed_timeout() > 0
    end
  end

  describe "handle_message/2 (default opts)" do
    test "returns {:error, :no_user} when called with 2 args and no existing thread" do
      assert {:error, :no_user} = Telegram.handle_message(99_900_001, "hi")
    end
  end

  describe "handle_voice/3" do
    test "delegates to handle_message and returns {:error, :no_user} when no user_id and no thread" do
      # Voice with no existing thread and no user_id falls through to handle_new_thread -> no_user
      assert {:error, :no_user} = Telegram.handle_voice(99_999_001, <<1, 2, 3>>, [])
    end

    test "creates a session and routes voice message when user_id provided" do
      user = create_user("tg_voice@example.com")
      thread_id = 88_001

      result =
        Telegram.handle_voice(thread_id, <<1, 2, 3>>, user_id: user.id)

      assert {:ok, _session_id} = result
    end

    test "uses placeholder text for voice transcription" do
      user = create_user("tg_voice_text@example.com")
      thread_id = 88_002

      {:ok, session_id} = Telegram.handle_voice(thread_id, <<>>, user_id: user.id)

      messages = Sessions.list_messages(session_id)
      assert Enum.any?(messages, fn m -> String.contains?(m.content, "Voice message") end)
    end
  end

  describe "handle_command/3" do
    test "/sessions command returns recent sessions list for user" do
      user = create_user("tg_cmd_sessions@example.com")
      create_session(user)

      assert {:ok, response} = Telegram.handle_command("/sessions", [], user_id: user.id)
      assert String.contains?(response, "Recent sessions")
    end

    test "/sessions command returns formatted list with session names" do
      user = create_user("tg_cmd_session_names@example.com")
      {:ok, _session} = Sessions.create_session(%{user_id: user.id, name: "My Work Session"})

      {:ok, response} = Telegram.handle_command("/sessions", [], user_id: user.id)
      assert String.contains?(response, "My Work Session")
    end

    test "/sessions command returns empty result when user has no sessions" do
      user = create_user("tg_cmd_empty@example.com")
      {:ok, response} = Telegram.handle_command("/sessions", [], user_id: user.id)
      assert String.contains?(response, "Recent sessions")
    end

    test "unknown command returns helpful message" do
      user = create_user("tg_cmd_unknown@example.com")
      assert {:ok, response} = Telegram.handle_command("/unknown", [], user_id: user.id)
      assert String.contains?(response, "Unknown command")
    end

    test "unknown command suggests available commands" do
      user = create_user("tg_cmd_suggest@example.com")
      {:ok, response} = Telegram.handle_command("/bogus", [], user_id: user.id)
      assert String.contains?(response, "/sessions")
    end
  end

  describe "handle_message/3" do
    test "returns {:error, :no_user} when no existing thread and no user_id" do
      assert {:error, :no_user} = Telegram.handle_message(99_999_999, "Hello", [])
    end

    test "creates a new session for a new thread when user_id is given" do
      user = create_user("tg_new_thread@example.com")
      thread_id = 77_001

      assert {:ok, session_id} = Telegram.handle_message(thread_id, "Hello", user_id: user.id)
      assert is_binary(session_id)
    end

    test "stores the message content in the new session" do
      user = create_user("tg_msg_content@example.com")
      thread_id = 77_002

      {:ok, session_id} = Telegram.handle_message(thread_id, "Test content", user_id: user.id)
      messages = Sessions.list_messages(session_id)
      assert Enum.any?(messages, fn m -> m.content == "Test content" end)
    end

    test "routes subsequent messages to existing session thread" do
      user = create_user("tg_existing_thread@example.com")
      thread_id = 77_003

      {:ok, session_id_1} = Telegram.handle_message(thread_id, "First", user_id: user.id)
      {:ok, session_id_2} = Telegram.handle_message(thread_id, "Second", user_id: user.id)

      assert session_id_1 == session_id_2
    end
  end
end
