defmodule JamesCli.Repl do
  @moduledoc """
  Interactive REPL for chatting with a James session.

  Reads lines from stdin, sends them to the server, and prints the response.
  Uses `JamesCli.Tui` for ANSI-colored output (Claude Code-like TUI style).
  Exits on `quit`, `exit`, `\\q`, or EOF.
  """

  alias JamesCli.{Client, Formatter, Tui}

  @doc """
  Starts the interactive REPL loop for `session_id`.

  Options:
  - `:config` — config map (required)
  - `:format` — output format atom (default: :text)
  - `:io`     — IO module to use (default: IO, injectable for tests)
  """
  def start(session_id, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    format = Keyword.get(opts, :format, :text)
    io = Keyword.get(opts, :io, IO)

    io.puts(Tui.header(session_id))
    io.puts(Tui.status_line("Type 'quit' or Ctrl-D to exit"))
    io.puts("")
    loop(session_id, config, format, io)
  end

  defp loop(session_id, config, format, io) do
    prompt = colored_prompt()

    case io.gets(prompt) do
      :eof ->
        io.puts("")
        :ok

      {:error, _} ->
        :ok

      input ->
        handle_input(String.trim(input), session_id, config, format, io)
    end
  end

  defp handle_input(trimmed, session_id, config, format, io) do
    cond do
      trimmed in ["quit", "exit", "\\q"] ->
        io.puts(IO.ANSI.format([:faint, "Goodbye.", :reset]) |> IO.chardata_to_string())
        :ok

      trimmed == "" ->
        loop(session_id, config, format, io)

      true ->
        send_and_continue(trimmed, session_id, config, format, io)
    end
  end

  defp send_and_continue(input, session_id, config, format, io) do
    spinner = Tui.start_spinner("thinking")

    result =
      try do
        Client.chat(config, session_id, input)
      after
        Tui.stop_spinner(spinner)
      end

    case result do
      {:ok, response} ->
        text = Formatter.format(response, format)
        io.puts(Tui.format_assistant(text))

      {:error, err} ->
        msg = IO.ANSI.format([:red, "Error: #{inspect(err)}", :reset]) |> IO.chardata_to_string()
        io.puts(msg)
    end

    io.puts("")
    loop(session_id, config, format, io)
  end

  defp colored_prompt do
    IO.ANSI.format([:bright, :yellow, "❯ ", :reset]) |> IO.chardata_to_string()
  end
end
