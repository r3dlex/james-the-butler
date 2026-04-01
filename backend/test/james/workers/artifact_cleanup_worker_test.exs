defmodule James.Workers.ArtifactCleanupWorkerTest do
  use James.DataCase

  alias James.{Accounts, Artifacts, Hosts, Sessions, Tasks}
  alias James.Workers.ArtifactCleanupWorker

  defp setup_context do
    {:ok, user} = Accounts.create_user(%{email: "acw_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "acw-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9800"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "ACW Session"})

    {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "test"})
    %{session: session, task: task}
  end

  describe "perform/1" do
    test "cleans non-deliverable artifacts for the task" do
      %{session: session, task: task} = setup_context()

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, task_id: task.id, type: "file"})

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, task_id: task.id, type: "file"})

      assert :ok == ArtifactCleanupWorker.perform(%Oban.Job{args: %{"task_id" => task.id}})

      uncleaned = Artifacts.list_artifacts(task_id: task.id, uncleaned_only: true)
      assert uncleaned == []
    end

    test "preserves deliverable artifacts" do
      %{session: session, task: task} = setup_context()

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          task_id: task.id,
          type: "document",
          is_deliverable: true
        })

      assert :ok == ArtifactCleanupWorker.perform(%Oban.Job{args: %{"task_id" => task.id}})

      uncleaned = Artifacts.list_artifacts(task_id: task.id, uncleaned_only: true)
      assert length(uncleaned) == 1
    end

    test "succeeds with unknown task_id" do
      unknown = Ecto.UUID.generate()
      assert :ok == ArtifactCleanupWorker.perform(%Oban.Job{args: %{"task_id" => unknown}})
    end
  end
end
