defmodule JamesCli.ConfigTest do
  use ExUnit.Case, async: true

  alias JamesCli.Config

  @tmp_dir System.tmp_dir!()

  defp tmp_config_path do
    Path.join(@tmp_dir, "james_test_#{:rand.uniform(999_999)}.toml")
  end

  describe "load/1" do
    test "returns default config when file does not exist" do
      config = Config.load("/nonexistent/path/james.toml")
      assert is_map(config)
      assert Map.has_key?(config, "server")
    end

    test "loads TOML config from file" do
      path = tmp_config_path()

      File.write!(path, """
      [server]
      url = "http://myserver:4000"
      token = "my-token"
      """)

      config = Config.load(path)
      assert config["server"]["url"] == "http://myserver:4000"
      assert config["server"]["token"] == "my-token"

      File.rm(path)
    end

    test "merges with defaults for missing keys" do
      path = tmp_config_path()

      File.write!(path, """
      [server]
      token = "only-token"
      """)

      config = Config.load(path)
      assert config["server"]["token"] == "only-token"
      # URL should fall back to default
      assert Map.has_key?(config["server"], "url")

      File.rm(path)
    end
  end

  describe "default_path/0" do
    test "returns path under home directory" do
      path = Config.default_path()
      assert String.contains?(path, ".james")
      assert String.ends_with?(path, "config.toml")
    end
  end

  describe "get/3" do
    test "retrieves nested value by key path" do
      config = %{"server" => %{"url" => "http://localhost:4000"}}
      assert Config.get(config, ["server", "url"]) == "http://localhost:4000"
    end

    test "returns default when key is missing" do
      config = %{"server" => %{}}
      assert Config.get(config, ["server", "token"], "fallback") == "fallback"
    end

    test "returns nil default when not specified" do
      config = %{}
      assert Config.get(config, ["missing"]) == nil
    end
  end
end
