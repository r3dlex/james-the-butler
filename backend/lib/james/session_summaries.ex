defmodule James.SessionSummaries do
  @moduledoc """
  Manages per-session summaries — the live second memory tier.

  Each session has at most one summary row. Use `create_or_update_summary/1`
  to upsert on `session_id`.
  """

  import Ecto.Query
  alias James.Repo
  alias James.SessionSummaries.SessionSummary

  @doc """
  Upserts a session summary. If a summary already exists for the given
  `session_id`, all fields are replaced with the new values.
  """
  def create_or_update_summary(attrs) do
    %SessionSummary{}
    |> SessionSummary.changeset(attrs)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :session_id
    )
  end

  @doc """
  Returns the summary for a session, or `nil` if none exists.
  """
  def get_summary(session_id) do
    Repo.get_by(SessionSummary, session_id: session_id)
  end

  @doc """
  Returns the summary for a session if it was updated within the last
  `max_age_minutes` minutes, otherwise returns `nil`.
  """
  def get_fresh_summary(session_id, max_age_minutes) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_minutes, :minute)

    Repo.one(
      from s in SessionSummary,
        where: s.session_id == ^session_id and s.updated_at >= ^cutoff
    )
  end

  @doc """
  Deletes a session summary.
  """
  def delete_summary(%SessionSummary{} = summary) do
    Repo.delete(summary)
  end

  @doc """
  Returns `true` if a summary exists for the given session, `false` otherwise.
  """
  def summary_exists?(session_id) do
    Repo.exists?(from s in SessionSummary, where: s.session_id == ^session_id)
  end
end
