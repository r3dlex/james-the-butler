defmodule James.Cron do
  @moduledoc """
  Context for agent self-scheduling via cron tasks.

  Each `CronTask` belongs to a session and fires at times determined by a
  5-field cron expression, injecting a configured prompt into the session.
  """

  import Ecto.Query

  alias James.Cron.{CronTask, Parser}
  alias James.Repo

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc "Returns a single cron task by id, or nil."
  def get_cron_task(id), do: Repo.get(CronTask, id)

  @doc "Returns a single cron task by id, raising if not found."
  def get_cron_task!(id), do: Repo.get!(CronTask, id)

  @doc "Creates a cron task from the given attributes."
  def create_cron_task(attrs) do
    %CronTask{}
    |> CronTask.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a cron task with the given attributes."
  def update_cron_task(%CronTask{} = task, attrs) do
    task
    |> CronTask.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a cron task."
  def delete_cron_task(%CronTask{} = task) do
    Repo.delete(task)
  end

  @doc "Disables a cron task (sets enabled: false)."
  def disable_cron_task(%CronTask{} = task) do
    task
    |> CronTask.changeset(%{enabled: false})
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Lists all cron tasks for a given session_id."
  def list_cron_tasks(session_id) do
    Repo.all(from t in CronTask, where: t.session_id == ^session_id)
  end

  @doc "Alias for list_cron_tasks/1 — returns only that session's tasks."
  def list_cron_tasks_for_session(session_id), do: list_cron_tasks(session_id)

  @doc """
  Returns all enabled cron tasks whose `next_fire_at` is at or before now
  and whose `expires_at` is either nil or in the future.
  """
  def list_due_tasks do
    now = DateTime.utc_now()

    Repo.all(
      from t in CronTask,
        where:
          t.enabled == true and
            t.next_fire_at <= ^now and
            (is_nil(t.expires_at) or t.expires_at > ^now)
    )
  end

  # ---------------------------------------------------------------------------
  # Fire-cycle helpers
  # ---------------------------------------------------------------------------

  @doc """
  Updates a task after it has been fired.

  - Sets `last_fired_at` to now.
  - For recurring tasks: computes and sets `next_fire_at`.
  - For non-recurring tasks: disables the task.
  """
  def update_after_fire(%CronTask{recurring: true} = task) do
    now = DateTime.utc_now()

    {:ok, next} = Parser.next_fire_at(task.cron_expression, now)

    task
    |> CronTask.changeset(%{last_fired_at: now, next_fire_at: next})
    |> Repo.update()
  end

  def update_after_fire(%CronTask{recurring: false} = task) do
    now = DateTime.utc_now()

    task
    |> CronTask.changeset(%{last_fired_at: now, enabled: false})
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Utility
  # ---------------------------------------------------------------------------

  @doc """
  Computes the expiry DateTime by adding `max_age_days` days to `inserted_at`.
  """
  def compute_expires_at(%CronTask{inserted_at: inserted_at, max_age_days: days}) do
    DateTime.add(inserted_at, days * 24 * 3600, :second)
  end
end
