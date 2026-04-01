defmodule James.Workers.ArtifactCleanupWorker do
  @moduledoc """
  Oban worker that cleans up working (non-deliverable) artifacts for a completed task.
  Enqueued by the orchestrator when a task transitions to completed or failed.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 3

  alias James.{Artifacts, Sessions}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    {:ok, _count} = Artifacts.clean_task_artifacts(task_id)
    :ok
  end

  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    session = Sessions.get_session(session_id)

    if session && !session.keep_intermediates do
      {:ok, _count} = Artifacts.clean_session_working_files(session_id)
    end

    :ok
  end
end
