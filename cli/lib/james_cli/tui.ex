defmodule JamesCli.Tui do
  @moduledoc """
  Simple ANSI TUI helpers for the interactive REPL.

  Provides colored output, spinners, and formatted assistant/user messages.
  This is a lightweight ANSI-only TUI — not Ratatui (which requires Rust).
  """

  @spinner_chars ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

  @doc "Returns the session header."
  def header(session_id) do
    [
      :cyan,
      "\n╔══════════════════════════════════════════════╗\n",
      "║  James CLI — Session #{String.pad_trailing(session_id, 20)}║\n",
      "╚══════════════════════════════════════════════╝",
      :reset
    ]
    |> IO.ANSI.format()
    |> IO.chardata_to_string()
  end

  @doc "Returns a status line in faint gray."
  def status_line(text) do
    IO.ANSI.format([:faint, text]) |> IO.chardata_to_string()
  end

  @doc "Formats a message from the assistant (server) in green."
  def format_assistant(text) do
    [:green, "assistant: ", :reset, text]
    |> IO.ANSI.format()
    |> IO.chardata_to_string()
  end

  @doc "Formats a user input echo."
  def format_user(text) do
    [:bright, :blue, "you: ", :reset, text]
    |> IO.ANSI.format()
    |> IO.chardata_to_string()
  end

  @doc "Starts a text spinner. Returns a pid."
  def start_spinner(label) do
    spawn(fn -> spinner_loop(label, 0) end)
  end

  @doc "Stops a spinner given its pid."
  def stop_spinner(pid) do
    send(pid, :stop)
  end

  defp spinner_loop(label, idx) do
    char = Enum.at(@spinner_chars, rem(idx, length(@spinner_chars)))
    msg = IO.ANSI.format([:cyan, "\r#{char} ", :faint, label, :reset]) |> IO.chardata_to_string()

    receive do
      :stop ->
        IO.write("\r" <> String.duplicate(" ", 60) <> "\r")
        :ok
    after
      80 ->
        IO.write(msg)
        spinner_loop(label, idx + 1)
    end
  end
end
