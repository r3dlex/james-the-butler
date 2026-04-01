defmodule James.Sessions.AwayDetector do
  @moduledoc """
  Detects whether a user returning to a session needs a summary of background
  activity that occurred while they were away.

  ## Usage

      case AwayDetector.on_resume(session_id) do
        :no_summary_needed -> :ok
        {:inject, summary}  -> push_summary_to_client(summary)
      end

  ## Decision logic

  A summary is injected only when **all** of the following are true:

  1. The session has been idle for at least `threshold_minutes` (default: 5).
  2. At least one background task completed since the last user message.
  3. An away summary has not already been injected since the last user message.

  The idle duration is measured from the session's `last_used_at` timestamp.
  """

  import Ecto.Query
  alias James.Repo
  alias James.Sessions.{Message, Session}
  alias James.Tasks.Task

  @default_threshold_minutes 5

  @doc """
  Checks whether an away summary should be injected for `session_id`.

  Returns:
  - `:no_summary_needed` — session was active recently, no background tasks
    completed, or a summary was already injected since the last user message.
  - `{:inject, summary_text}` — the client should display this summary.

  ## Options

    * `:threshold_minutes` — idle time required before a summary is generated
      (default: #{@default_threshold_minutes}).
    * `:now` — `DateTime` used as "current time" (default: `DateTime.utc_now/0`).
  """
  @spec on_resume(binary(), keyword()) :: :no_summary_needed | {:inject, String.t()}
  def on_resume(session_id, opts \\ []) do
    threshold = Keyword.get(opts, :threshold_minutes, @default_threshold_minutes)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    session = Repo.get(Session, session_id)

    if is_nil(session) do
      :no_summary_needed
    else
      idle_minutes = idle_minutes(session, now)

      if idle_minutes < threshold do
        :no_summary_needed
      else
        check_background_tasks(session_id)
      end
    end
  end

  @doc """
  Builds a human-readable summary text from a list of completed tasks.

  Each task is represented as a bullet point with its description and status.
  """
  @spec build_away_summary(list(map()), keyword()) :: String.t()
  def build_away_summary(tasks, _opts \\ []) do
    task_lines =
      Enum.map_join(tasks, "\n", fn task ->
        "- #{task.description} (#{task.status})"
      end)

    """
    While you were away, the following background tasks completed:

    #{task_lines}
    """
    |> String.trim_trailing()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp idle_minutes(session, now) do
    reference =
      session.last_used_at ||
        session.inserted_at

    DateTime.diff(now, reference, :second) / 60.0
  end

  defp check_background_tasks(session_id) do
    last_user_msg_at = last_user_message_at(session_id)

    completed_tasks =
      tasks_completed_since(session_id, last_user_msg_at || epoch())

    if completed_tasks == [] do
      :no_summary_needed
    else
      already_injected? = away_summary_already_injected?(session_id, last_user_msg_at)

      if already_injected? do
        :no_summary_needed
      else
        summary = build_away_summary(completed_tasks)
        {:inject, summary}
      end
    end
  end

  defp last_user_message_at(session_id) do
    Repo.one(
      from m in Message,
        where: m.session_id == ^session_id and m.role == "user",
        order_by: [desc: m.inserted_at],
        limit: 1,
        select: m.inserted_at
    )
  end

  defp tasks_completed_since(session_id, since) do
    Repo.all(
      from t in Task,
        where:
          t.session_id == ^session_id and
            t.status == "completed" and
            t.completed_at >= ^since
    )
  end

  # Check whether a "planner" role message with away-summary content was
  # injected after the last user message.
  defp away_summary_already_injected?(session_id, last_user_msg_at) do
    since = last_user_msg_at || epoch()

    Repo.exists?(
      from m in Message,
        where:
          m.session_id == ^session_id and
            m.role == "planner" and
            m.inserted_at >= ^since and
            like(m.content, "%While you were away%")
    )
  end

  defp epoch, do: ~U[1970-01-01 00:00:00Z]
end
