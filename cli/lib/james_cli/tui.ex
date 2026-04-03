defmodule JamesCli.Tui do
  @moduledoc """
  Terminal UI helpers for James CLI.

  Provides ANSI-colored formatting for user messages, assistant responses,
  spinner frames, session headers, and status lines — giving the CLI a
  Claude Code-like interactive appearance.
  """

  @user_prefix "❯ "
  @spinner_frames ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

  @doc "Formats a user-typed message with bold gold styling and a '❯' prefix."
  @spec format_user(String.t()) :: String.t()
  def format_user(message) do
    IO.ANSI.format([:bright, :yellow, @user_prefix, :reset, :bright, message, :reset], true)
    |> IO.chardata_to_string()
  end

  @doc "Formats an assistant response with default text color and a trailing reset."
  @spec format_assistant(String.t()) :: String.t()
  def format_assistant(message) do
    IO.ANSI.format([:default_color, message, :reset], true)
    |> IO.chardata_to_string()
  end

  @doc "Returns the list of spinner animation frame strings."
  @spec spinner_frames() :: [String.t()]
  def spinner_frames, do: @spinner_frames

  @doc "Returns a styled header line showing the session id."
  @spec header(String.t()) :: String.t()
  def header(session_id) do
    IO.ANSI.format(
      [
        :bright,
        :cyan,
        "─── James ",
        :reset,
        :cyan,
        "· session ",
        :bright,
        session_id,
        :reset,
        :cyan,
        " ───",
        :reset
      ],
      true
    )
    |> IO.chardata_to_string()
  end

  @doc "Returns a styled dim status line (e.g. 'thinking…')."
  @spec status_line(String.t()) :: String.t()
  def status_line(text) do
    IO.ANSI.format([:faint, :italic, text, :reset], true)
    |> IO.chardata_to_string()
  end

  @doc """
  Spawns a spinner in a background task.  Call `stop_spinner/1` with the
  returned pid to stop it and clear the line.
  """
  @spec start_spinner(String.t()) :: pid()
  def start_spinner(label \\ "thinking") do
    spawn(fn -> spin_loop(@spinner_frames, label) end)
  end

  @doc "Stops a running spinner and clears the spinner line."
  @spec stop_spinner(pid()) :: :ok
  def stop_spinner(pid) do
    Process.exit(pid, :kill)
    # Clear the spinner line
    IO.write("\r" <> String.duplicate(" ", 40) <> "\r")
    :ok
  end

  # --- Private ---

  defp spin_loop(frames, label) do
    Enum.each(Stream.cycle(frames), fn frame ->
      IO.write("\r" <> status_line("#{frame} #{label}..."))
      Process.sleep(100)
    end)
  end
end
