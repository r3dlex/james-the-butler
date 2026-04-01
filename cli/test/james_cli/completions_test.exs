defmodule JamesCli.CompletionsTest do
  use ExUnit.Case, async: true

  alias JamesCli.Completions

  describe "bash_script/0" do
    test "returns a non-empty bash completion script" do
      script = Completions.bash_script()
      assert is_binary(script)
      assert String.length(script) > 50
      assert script =~ "james"
      assert script =~ "_james_completions"
    end
  end

  describe "zsh_script/0" do
    test "returns a non-empty zsh completion script" do
      script = Completions.zsh_script()
      assert is_binary(script)
      assert script =~ "james"
    end
  end

  describe "fish_script/0" do
    test "returns a non-empty fish completion script" do
      script = Completions.fish_script()
      assert is_binary(script)
      assert script =~ "james"
    end
  end

  describe "commands/0" do
    test "returns a list of top-level commands" do
      commands = Completions.commands()
      assert is_list(commands)
      assert "session" in commands
      assert "chat" in commands
      assert "skill" in commands
    end
  end

  describe "subcommands/1" do
    test "returns subcommands for session" do
      subs = Completions.subcommands("session")
      assert is_list(subs)
      assert "list" in subs
      assert "show" in subs
    end

    test "returns empty list for unknown command" do
      assert Completions.subcommands("unknown-xyz") == []
    end
  end
end
