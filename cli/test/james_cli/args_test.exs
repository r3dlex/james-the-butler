defmodule JamesCli.ArgsTest do
  use ExUnit.Case, async: true

  alias JamesCli.Args

  describe "parse/1" do
    test "parses --format flag as atom" do
      assert %{format: :json} = Args.parse(["session", "list", "--format", "json"])
      assert %{format: :stream_json} = Args.parse(["chat", "--format", "stream_json"])
    end

    test "defaults format to :text" do
      result = Args.parse(["session", "list"])
      assert result.format == :text
    end

    test "extracts subcommand and args" do
      result = Args.parse(["session", "list"])
      assert result.command == "session"
      assert result.subcommand == "list"
    end

    test "handles --non-interactive flag" do
      result = Args.parse(["chat", "--non-interactive"])
      assert result.non_interactive == true
    end

    test "defaults non_interactive to false" do
      result = Args.parse(["session", "list"])
      assert result.non_interactive == false
    end

    test "parses --config flag with a path" do
      result = Args.parse(["--config", "/tmp/my.toml", "session", "list"])
      assert result.config_path == "/tmp/my.toml"
    end

    test "handles --version flag" do
      result = Args.parse(["--version"])
      assert result.version == true
    end

    test "handles --help flag" do
      result = Args.parse(["--help"])
      assert result.help == true
    end

    test "unknown flags are collected as extras" do
      result = Args.parse(["session", "list", "--limit", "10"])
      assert result.extras["limit"] == "10"
    end
  end
end
