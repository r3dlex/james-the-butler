defmodule James.Codebase.GitParser do
  @moduledoc """
  Pure-Elixir git parsing using System.cmd.
  Parses porcelain git output into structured data.
  """

  @doc """
  Parse git status --porcelain output into structured form.

  Status codes:
  - "M" → :modified
  - "A" → :added
  - "D" → :deleted
  - "R" → :renamed
  - "C" → :copied
  - "??" → :untracked
  - "UU" → :unmerged
  """
  @spec parse_status(dir :: String.t()) ::
          {:ok, [%{path: String.t(), status: atom()}]} | {:error, String.t()}
  def parse_status(dir) do
    case System.cmd("git", ["status", "--porcelain"], cd: dir) do
      {output, 0} ->
        statuses =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_status_line/1)

        {:ok, statuses}

      {error, _exit_code} ->
        {:error, String.trim(error)}
    end
  end

  @doc """
  Parse git diff --stat output into structured form.
  Returns a list of %{file: String.t(), additions: non_neg_integer(), deletions: non_neg_integer()}.
  """
  @spec parse_diff_summary(dir :: String.t()) ::
          {:ok, [%{file: String.t(), additions: non_neg_integer(), deletions: non_neg_integer()}]}
          | {:error, String.t()}
  def parse_diff_summary(dir) do
    case System.cmd("git", ["diff", "--stat"], cd: dir) do
      {output, 0} ->
        summary =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_stat_line/1)
          |> Enum.reject(&is_nil/1)

        {:ok, summary}

      {error, _exit_code} ->
        {:error, String.trim(error)}
    end
  end

  # ─── Test-friendly wrappers ─────────────────────────────────────────────────

  @doc "Parses a single status line. For use in tests only."
  @spec parse_status_line(String.t()) :: %{path: String.t(), status: atom()} | nil
  def parse_status_line(line), do: do_parse_status_line(line)

  @doc "Parses a single diff stat line. For use in tests only."
  @spec parse_stat_line(String.t()) ::
          %{file: String.t(), additions: non_neg_integer(), deletions: non_neg_integer()}
          | nil
  def parse_stat_line(line), do: do_parse_stat_line(line)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp do_parse_status_line(line) do
    # Porcelain format: XY filename
    # X = index status, Y = working tree status
    # We take the more meaningful of the two
    case String.split(line, " ", parts: 2) do
      [codes, path] ->
        status = code_to_status(codes)
        %{path: path, status: status}

      _ ->
        nil
    end
  end

  defp code_to_status(codes) do
    # Check for unmerged (UU) first
    if String.contains?(codes, "U") do
      :unmerged
    else
      # Take the first character as the primary status
      # Priority: M > A > D > R > C > ? > !
      first = String.first(codes)

      case first do
        "M" -> :modified
        "A" -> :added
        "D" -> :deleted
        "R" -> :renamed
        "C" -> :copied
        "?" -> :untracked
        "!" -> :ignored
        _ -> :unknown
      end
    end
  end

  defp do_parse_stat_line(line) do
    # Format: " file | 10 +++ 5 ----"
    # or: " 10 files changed, 100 insertions(+), 50 deletions(-)"
    # We want the per-file entries
    case String.split(line, "|") do
      [file, stats] ->
        case parse_stats(stats) do
          {additions, deletions} ->
            %{file: String.trim(file), additions: additions, deletions: deletions}

          nil ->
            nil
        end

      _ ->
        nil
    end
  end

  defp parse_stats(stats) do
    stats = String.trim(stats)

    with true <- String.contains?(stats, "+"),
         {add_str, rest} <- Integer.parse(stats),
         true <- String.starts_with?(rest, " +"),
         {del_str, _} <- Integer.parse(String.trim_leading(rest, " +")) do
      {add_str, del_str}
    else
      _ -> nil
    end
  end
end
