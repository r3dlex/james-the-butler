defmodule JamesCli.Main do
  @moduledoc """
  Escript entry point for the James CLI.

  Usage:
    james [options] <command> [subcommand] [flags]

  Run `james --help` for full usage information.
  """

  alias JamesCli.{Args, Commands, Config, Repl}

  @doc "Main escript entry point."
  def main(argv) do
    args = Args.parse(argv)
    config_path = args.config_path || Config.default_path()
    config = Config.load(config_path)

    if args.command == "chat" and not args.non_interactive do
      run_interactive(args, config)
    else
      run_command(args, config)
    end
  end

  defp run_command(args, config) do
    case Commands.dispatch(args, config) do
      {:ok, output} ->
        IO.puts(output)
        System.halt(0)

      {:error, message} ->
        IO.puts(:stderr, "Error: #{message}")
        System.halt(1)
    end
  end

  defp run_interactive(args, config) do
    # Start a session or use provided session id
    session_id = Map.get(args.extras, "session")

    case session_id do
      nil ->
        IO.puts(:stderr, "Error: --session <id> is required for chat REPL.")
        System.halt(1)

      id ->
        Repl.start(id, config: config, format: args.format)
    end
  end
end
