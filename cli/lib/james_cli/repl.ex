defmodule JamesCli.Repl do
  @moduledoc """
  Interactive REPL for chatting with a James session.

  Reads lines from stdin, sends them to the server, and prints the response.
  Exits on `quit`, `exit`, or EOF.
  """

  alias JamesCli.{Client, Formatter}

  @prompt "james> "

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

    io.puts("James REPL — session #{session_id}. Type 'quit' or Ctrl-D to exit.\n")
    loop(session_id, config, format, io)
  end

  defp loop(session_id, config, format, io) do
    case io.gets(@prompt) do
      :eof ->
        :ok

      {:error, _} ->
        :ok

      input ->
        trimmed = String.trim(input)

        cond do
          trimmed in ["quit", "exit", "\\q"] ->
            io.puts("Goodbye.")
            :ok

          trimmed == "" ->
            loop(session_id, config, format, io)

          true ->
            case Client.chat(config, session_id, trimmed) do
              {:ok, response} ->
                io.puts(Formatter.format(response, format))

              {:error, err} ->
                io.puts("Error: #{inspect(err)}")
            end

            loop(session_id, config, format, io)
        end
    end
  end
end
