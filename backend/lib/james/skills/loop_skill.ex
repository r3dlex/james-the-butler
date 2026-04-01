defmodule James.Skills.LoopSkill do
  @moduledoc """
  Skill that creates, lists, or removes recurring cron tasks for the current
  session using human-friendly interval shorthand.

  ## Interval shorthand

  | Input | Cron expression |
  |-------|----------------|
  | `5m`  | `*/5 * * * *`  |
  | `1h`  | `0 */1 * * *`  |
  | `30s` | *(nearest minute, e.g. `* * * * *`)* |
  | `stop` | deletes all cron tasks for the session |
  | `list` | returns the current task list         |

  ## Usage

      LoopSkill.execute("5m", %{session_id: session_id, prompt: "Check email"})
  """

  alias James.Agents.Tools.CronTools

  @doc """
  Parses the interval shorthand and delegates to `CronTools.execute/3`.

  Returns `{:ok, message}` or `{:error, message}`.
  """
  @spec execute(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def execute("stop", state) do
    CronTools.execute("cron_list", %{}, state)
    |> case do
      {:ok, "No cron tasks" <> _} ->
        {:ok, "No active loop tasks to stop."}

      {:ok, _} ->
        delete_all_tasks(state)

      {:error, _} = err ->
        err
    end
  end

  def execute("list", state) do
    CronTools.execute("cron_list", %{}, state)
  end

  def execute(interval, state) when is_binary(interval) do
    case parse_interval(interval) do
      {:ok, cron_expr} ->
        prompt = Map.get(state, :prompt, Map.get(state, "prompt", "Scheduled loop task"))
        params = %{"cron" => cron_expr, "prompt" => prompt}

        case CronTools.execute("cron_schedule", params, state) do
          {:ok, msg} ->
            {:ok, "Loop set to #{interval} (#{cron_expr}). #{msg}"}

          {:error, _} = err ->
            err
        end

      {:error, :invalid_interval} ->
        {:error, "Invalid interval: #{inspect(interval)}. Use formats like 5m, 1h, 30m."}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Converts human-readable shorthand to a 5-field cron expression.
  # Supports Nm (minutes) and Nh (hours). Seconds are rounded to the nearest
  # full-minute equivalent.
  defp parse_interval(str) do
    cond do
      Regex.match?(~r/^\d+s$/, str) ->
        # Sub-minute intervals collapse to every-minute
        {:ok, "* * * * *"}

      Regex.match?(~r/^\d+m$/, str) ->
        n = str |> String.trim_trailing("m") |> String.to_integer()
        cron = if n == 1, do: "* * * * *", else: "*/#{n} * * * *"
        {:ok, cron}

      Regex.match?(~r/^\d+h$/, str) ->
        n = str |> String.trim_trailing("h") |> String.to_integer()
        {:ok, "0 */#{n} * * *"}

      true ->
        {:error, :invalid_interval}
    end
  end

  defp delete_all_tasks(state) do
    alias James.Cron

    tasks = Cron.list_cron_tasks_for_session(state.session_id)

    Enum.each(tasks, fn task ->
      Cron.delete_cron_task(task)
    end)

    {:ok, "Stopped #{length(tasks)} loop task(s) for this session."}
  end
end
