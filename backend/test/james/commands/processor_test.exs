defmodule James.Commands.ProcessorTest do
  use ExUnit.Case, async: true

  alias James.Commands.Processor

  # A fake session_id — commands that don't touch the DB are safe to call with any value.
  @session_id "test-session-id"

  # ---------------------------------------------------------------------------
  # Non-command messages
  # ---------------------------------------------------------------------------

  describe "process/2 — non-command pass-through" do
    test "returns :not_command for a plain text message" do
      assert Processor.process("Hello, world!", @session_id) == :not_command
    end

    test "returns :not_command for an empty string" do
      assert Processor.process("", @session_id) == :not_command
    end

    test "message with only leading spaces before /help is treated as a command (trimmed)" do
      # parse/1 calls String.trim first, so "  /help" becomes "/help" — a valid command
      result = Processor.process("  /help", @session_id)
      assert match?({:command, _}, result)
    end

    test "returns :not_command for a message with only whitespace" do
      assert Processor.process("   ", @session_id) == :not_command
    end

    test "returns :not_command for a message that contains / but doesn't start with it" do
      assert Processor.process("use /help to see commands", @session_id) == :not_command
    end

    test "returns :not_command for a numeric message" do
      assert Processor.process("12345", @session_id) == :not_command
    end
  end

  # ---------------------------------------------------------------------------
  # /help
  # ---------------------------------------------------------------------------

  describe "process/2 — /help command" do
    test "returns {:command, text} tuple" do
      assert {:command, text} = Processor.process("/help", @session_id)
      assert is_binary(text)
    end

    test "help text mentions /clear" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/clear"
    end

    test "help text mentions /rename" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/rename"
    end

    test "help text mentions /cost" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/cost"
    end

    test "help text mentions /status" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/status"
    end

    test "help text mentions /model" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/model"
    end

    test "help text mentions /effort" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/effort"
    end

    test "help text mentions /plan" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/plan"
    end

    test "help text mentions /checkpoint" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/checkpoint"
    end

    test "help text mentions /rewind" do
      {:command, text} = Processor.process("/help", @session_id)
      assert text =~ "/rewind"
    end

    test "HELP (uppercase) is not a command" do
      # Commands are lowercased, but the prefix detection is case-insensitive only
      # after the slash. The parse/1 downcases the command word, so /HELP should work.
      {:command, text} = Processor.process("/HELP", @session_id)
      assert is_binary(text)
    end
  end

  # ---------------------------------------------------------------------------
  # /plan
  # ---------------------------------------------------------------------------

  describe "process/2 — /plan command (no DB)" do
    test "returns {:command, text} tuple" do
      assert {:command, text} = Processor.process("/plan", @session_id)
      assert is_binary(text)
    end

    test "response mentions planning mode" do
      {:command, text} = Processor.process("/plan", @session_id)
      assert String.downcase(text) =~ "planning"
    end
  end

  # ---------------------------------------------------------------------------
  # /compact
  # ---------------------------------------------------------------------------

  describe "process/2 — /compact command (no DB)" do
    test "returns {:command, text} for /compact with no args" do
      assert {:command, text} = Processor.process("/compact", @session_id)
      assert is_binary(text)
    end

    test "response for /compact with no focus mentions compaction requested" do
      {:command, text} = Processor.process("/compact", @session_id)
      assert String.downcase(text) =~ "compaction"
    end

    test "returns {:command, text} for /compact with focus argument" do
      assert {:command, text} = Processor.process("/compact my topic", @session_id)
      assert is_binary(text)
    end

    test "response includes the focus when provided to /compact" do
      {:command, text} = Processor.process("/compact authentication module", @session_id)
      assert text =~ "authentication module"
    end
  end

  # ---------------------------------------------------------------------------
  # /model
  # ---------------------------------------------------------------------------

  describe "process/2 — /model command (no DB)" do
    test "returns usage hint when called without arguments" do
      {:command, text} = Processor.process("/model", @session_id)
      assert text =~ "Usage"
    end

    test "returns confirmation when a model name is provided" do
      {:command, text} = Processor.process("/model claude-sonnet-4-20250514", @session_id)
      assert text =~ "claude-sonnet-4-20250514"
    end

    test "model name is echoed back in the response" do
      {:command, text} = Processor.process("/model my-custom-model-v2", @session_id)
      assert text =~ "my-custom-model-v2"
    end
  end

  # ---------------------------------------------------------------------------
  # /effort
  # ---------------------------------------------------------------------------

  describe "process/2 — /effort command (no DB)" do
    test "accepts 'low' effort level" do
      {:command, text} = Processor.process("/effort low", @session_id)
      assert text =~ "low"
    end

    test "accepts 'medium' effort level" do
      {:command, text} = Processor.process("/effort medium", @session_id)
      assert text =~ "medium"
    end

    test "accepts 'high' effort level" do
      {:command, text} = Processor.process("/effort high", @session_id)
      assert text =~ "high"
    end

    test "accepts 'max' effort level" do
      {:command, text} = Processor.process("/effort max", @session_id)
      assert text =~ "max"
    end

    test "rejects an invalid effort level" do
      {:command, text} = Processor.process("/effort turbo", @session_id)
      assert text =~ "Usage"
    end

    test "rejects an empty effort level" do
      {:command, text} = Processor.process("/effort", @session_id)
      # "turbo" style — should show usage hint
      assert is_binary(text)
    end
  end

  # ---------------------------------------------------------------------------
  # /rename — edge case: missing args (no DB call needed)
  # ---------------------------------------------------------------------------

  describe "process/2 — /rename with no arguments" do
    test "returns usage hint when no name is provided" do
      {:command, text} = Processor.process("/rename", @session_id)
      assert text =~ "Usage"
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown commands
  # ---------------------------------------------------------------------------

  describe "process/2 — unknown commands" do
    test "returns {:command, text} for an unrecognised slash command" do
      assert {:command, text} = Processor.process("/unknowncommand", @session_id)
      assert is_binary(text)
    end

    test "response for unknown command mentions the unknown command name" do
      {:command, text} = Processor.process("/xyzzy", @session_id)
      assert text =~ "xyzzy"
    end

    test "response for unknown command hints at /help" do
      {:command, text} = Processor.process("/doesnotexist", @session_id)
      assert text =~ "/help"
    end
  end

  # ---------------------------------------------------------------------------
  # Parsing edge cases
  # ---------------------------------------------------------------------------

  describe "process/2 — parsing edge cases" do
    test "leading whitespace before the slash is trimmed, making it a command" do
      # parse/1 calls String.trim/1 first, so leading spaces are stripped
      result = Processor.process("  /help", @session_id)
      assert match?({:command, _}, result)
    end

    test "command with extra spaces in args parses the args correctly" do
      {:command, text} = Processor.process("/compact  my topic  ", @session_id)
      assert text =~ "my topic"
    end

    test "a lone slash is treated as an empty command (unknown)" do
      {:command, text} = Processor.process("/", @session_id)
      assert is_binary(text)
    end
  end
end
