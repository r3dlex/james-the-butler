defmodule JamesCli.TuiTest do
  use ExUnit.Case, async: true

  alias JamesCli.Tui

  describe "format_user/1" do
    test "wraps message in bold ANSI escape codes" do
      result = Tui.format_user("hello world")
      assert result =~ "hello world"
      # Should contain ANSI bold or color escape sequences
      assert result =~ "\e["
    end

    test "includes a user indicator prefix" do
      result = Tui.format_user("my message")
      # Should have some kind of 'you' or '>' indicator
      assert result =~ ~r/[>❯▶]/
    end
  end

  describe "format_assistant/1" do
    test "returns the message text" do
      result = Tui.format_assistant("response text")
      assert result =~ "response text"
    end

    test "includes ANSI reset at the end" do
      result = Tui.format_assistant("some reply")
      assert String.ends_with?(result, IO.ANSI.reset())
    end
  end

  describe "spinner_frames/0" do
    test "returns a non-empty list of frame strings" do
      frames = Tui.spinner_frames()
      assert is_list(frames)
      assert frames != []
      assert Enum.all?(frames, &is_binary/1)
    end
  end

  describe "header/1" do
    test "returns a styled header string containing the session id" do
      result = Tui.header("session-abc")
      assert result =~ "session-abc"
      assert result =~ "\e["
    end
  end

  describe "status_line/1" do
    test "returns a styled status string" do
      result = Tui.status_line("thinking...")
      assert result =~ "thinking..."
    end
  end
end
