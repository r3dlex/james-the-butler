defmodule JamesCli.Config do
  @moduledoc """
  Loads and manages CLI configuration from `~/.james/config.toml`.

  Configuration is a nested map. Missing keys fall back to built-in defaults.
  """

  @defaults %{
    "server" => %{
      "url" => "http://localhost:4000",
      "token" => nil
    },
    "output" => %{
      "format" => "text"
    }
  }

  @doc "Returns the default config file path."
  @spec default_path() :: String.t()
  def default_path do
    home = System.get_env("HOME") || System.user_home!()
    Path.join([home, ".james", "config.toml"])
  end

  @doc """
  Loads configuration from `path`. Returns defaults when the file is absent or
  unreadable. TOML parse errors are logged and defaults returned.
  """
  @spec load(String.t()) :: map()
  def load(path \\ default_path()) do
    case File.read(path) do
      {:ok, content} ->
        case Toml.decode(content) do
          {:ok, parsed} -> deep_merge(@defaults, parsed)
          {:error, _reason} -> @defaults
        end

      {:error, _} ->
        @defaults
    end
  end

  @doc """
  Retrieves a nested value from `config` by key `path` (list of string keys).
  Returns `default` when any key in the path is missing.
  """
  @spec get(map(), [String.t()], any()) :: any()
  def get(config, key_path, default \\ nil) do
    Enum.reduce_while(key_path, config, fn key, acc ->
      case Map.get(acc, key) do
        nil -> {:halt, default}
        value -> {:cont, value}
      end
    end)
  end

  defp deep_merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2), do: deep_merge(v1, v2), else: v2
    end)
  end

  defp deep_merge(_base, override), do: override
end
