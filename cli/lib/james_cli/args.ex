defmodule JamesCli.Args do
  @moduledoc """
  Parses CLI arguments into a structured map.

  Recognised global flags:
  - `--format json|stream_json|text` — output format (default: text)
  - `--non-interactive`              — headless/script mode
  - `--config <path>`                — custom config file path
  - `--version`                      — print version and exit
  - `--help`                         — print help and exit

  Any unrecognised `--key value` pairs are collected in `extras`.
  """

  @type parsed :: %{
          command: String.t() | nil,
          subcommand: String.t() | nil,
          format: :json | :stream_json | :text,
          non_interactive: boolean(),
          config_path: String.t() | nil,
          version: boolean(),
          help: boolean(),
          extras: map()
        }

  @valid_formats ~w[json stream_json text]

  @doc "Parses `argv` into a structured args map."
  @spec parse([String.t()]) :: parsed()
  def parse(argv) do
    {flags, positional} = extract_flags(argv)

    format =
      case Map.get(flags, "format") do
        f when f in @valid_formats -> String.to_atom(f)
        _ -> :text
      end

    [command | rest] = positional ++ [nil, nil]
    [subcommand | _] = rest ++ [nil]

    %{
      command: command,
      subcommand: subcommand,
      format: format,
      non_interactive: Map.get(flags, "non_interactive", false),
      config_path: Map.get(flags, "config"),
      version: Map.get(flags, "version", false),
      help: Map.get(flags, "help", false),
      extras: Map.drop(flags, ~w[format non_interactive config version help])
    }
  end

  defp extract_flags(argv) do
    extract_flags(argv, %{}, [])
  end

  defp extract_flags([], flags, positional) do
    {flags, Enum.reverse(positional)}
  end

  defp extract_flags(["--non-interactive" | rest], flags, positional) do
    extract_flags(rest, Map.put(flags, "non_interactive", true), positional)
  end

  defp extract_flags(["--version" | rest], flags, positional) do
    extract_flags(rest, Map.put(flags, "version", true), positional)
  end

  defp extract_flags(["--help" | rest], flags, positional) do
    extract_flags(rest, Map.put(flags, "help", true), positional)
  end

  defp extract_flags(["--" <> key, value | rest], flags, positional) do
    norm_key = String.replace(key, "-", "_")

    if String.starts_with?(value, "--") do
      # `value` is actually the next flag, not a value — treat key as boolean
      extract_flags([value | rest], Map.put(flags, norm_key, true), positional)
    else
      extract_flags(rest, Map.put(flags, norm_key, value), positional)
    end
  end

  defp extract_flags(["--" <> key | rest], flags, positional) do
    norm_key = String.replace(key, "-", "_")
    extract_flags(rest, Map.put(flags, norm_key, true), positional)
  end

  defp extract_flags([arg | rest], flags, positional) do
    extract_flags(rest, flags, [arg | positional])
  end
end
