defmodule JamesCli.TuiTest do
  use ExUnit.Case, async: true

  alias JamesCli.Tui

  describe "format_user/1" do
    test "returns the message text" do
      result = Tui.format_user("hello world")
      assert result =~ "hello world"
    end

    test "includes a user indicator prefix" do
      result = Tui.format_user("my message")
      assert result =~ "you:"
    end
  end

  describe "format_assistant/1" do
    test "returns the message text" do
      result = Tui.format_assistant("response text")
      assert result =~ "response text"
    end

    test "includes an assistant indicator prefix" do
      result = Tui.format_assistant("some reply")
      assert result =~ "assistant:"
    end
  end

  describe "header/1" do
    test "returns a styled header string containing the session id" do
      result = Tui.header("session-abc")
      assert result =~ "session-abc"
      assert result =~ "James CLI"
    end
  end

  describe "status_line/1" do
    test "returns a styled status string" do
      result = Tui.status_line("thinking...")
      assert result =~ "thinking..."
    end
  end

  describe "start_spinner/1 and stop_spinner/1" do
    test "start_spinner returns a pid" do
      pid = Tui.start_spinner("test")
      assert is_pid(pid)
      Tui.stop_spinner(pid)
    end
  end
end
