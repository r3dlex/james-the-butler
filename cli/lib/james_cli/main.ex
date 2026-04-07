defmodule JamesCli.Main do
  @moduledoc """
  Escript entry point for the James CLI.

  Usage:
    james [options] <command> [subcommand] [flags]

  Run `james --help` for full usage information.
  """

  alias JamesCli.{Args, Commands, Config, Repl}

  @tui_bin_path Path.expand("../cli/rust/target/debug/james-tui", __DIR__)

  @doc "Main escript entry point."
  def main(argv) do
    args = Args.parse(argv)
    config_path = args.config_path || Config.default_path()
    config = Config.load(config_path)

    cond do
      args.command == "tui" ->
        run_tui()

      args.command == "chat" and not args.non_interactive ->
        run_interactive(args, config)

      true ->
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

  defp run_tui do
    tui_path = System.find_executable("james-tui") || @tui_bin_path

    if File.exists?(tui_path) do
      james_url = System.get_env("JAMES_URL", "http://localhost:4000")
      System.put_env("JAMES_URL", james_url)

      port = Port.open({:spawn_executable, tui_path}, [:use_stdio, :stderr_to_stdout, :binary])

      receive do
        {^port, {:exit_status, 0}} -> System.halt(0)
        {^port, {:exit_status, code}} -> System.halt(code)
      end
    else
      IO.puts(:stderr, "James TUI not found at: #{tui_path}")

      IO.puts(
        :stderr,
        "Build it with: cd cli/cli/rust && cargo build && cd ../.. && mix escript.build"
      )

      IO.puts(:stderr, "Or run: james chat --session <id> --message \"hello\" for CLI chat")
      System.halt(1)
    end
  end

  defp run_interactive(args, config) do
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
