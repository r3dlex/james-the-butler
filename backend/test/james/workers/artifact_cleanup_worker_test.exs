defmodule James.Workers.ArtifactCleanupWorkerTest do
  use James.DataCase

  alias James.{Accounts, Artifacts, Hosts, Sessions, Tasks}
  alias James.Workers.ArtifactCleanupWorker

  defp setup_context(session_opts \\ []) do
    {:ok, user} = Accounts.create_user(%{email: "acw_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "acw-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9800"
      })

    session_attrs =
      [user_id: user.id, host_id: host.id, name: "ACW Session"]
      |> Keyword.merge(session_opts)
      |> Map.new()

    {:ok, session} = Sessions.create_session(session_attrs)
    {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "test"})
    %{session: session, task: task}
  end

  # ---------------------------------------------------------------------------
  # Existing task_id-based tests (preserved)
  # ---------------------------------------------------------------------------

  describe "perform/1 task_id" do
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

  # ---------------------------------------------------------------------------
  # New session_id / keep_intermediates tests
  # ---------------------------------------------------------------------------

  describe "perform/1 session_id with keep_intermediates" do
    test "deletes working_file artifacts when keep_intermediates is off" do
      %{session: session} = setup_context(keep_intermediates: false)

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "working_file"
        })

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "working_file"
        })

      assert :ok ==
               ArtifactCleanupWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})

      uncleaned = Artifacts.list_artifacts(session_id: session.id, uncleaned_only: true)
      assert uncleaned == []
    end

    test "preserves deliverable artifacts always (keep_intermediates off)" do
      %{session: session} = setup_context(keep_intermediates: false)

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "deliverable"
        })

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "working_file"
        })

      assert :ok ==
               ArtifactCleanupWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})

      uncleaned = Artifacts.list_artifacts(session_id: session.id, uncleaned_only: true)
      assert length(uncleaned) == 1
      assert hd(uncleaned).type == "deliverable"
    end

    test "preserves ALL artifacts when keep_intermediates is on" do
      %{session: session} = setup_context(keep_intermediates: true)

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "working_file"
        })

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "deliverable"
        })

      assert :ok ==
               ArtifactCleanupWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})

      uncleaned = Artifacts.list_artifacts(session_id: session.id, uncleaned_only: true)
      assert length(uncleaned) == 2
    end

    test "handles session with no artifacts gracefully" do
      %{session: session} = setup_context(keep_intermediates: false)

      assert :ok ==
               ArtifactCleanupWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})
    end

    test "handles unknown session_id gracefully" do
      unknown = Ecto.UUID.generate()

      assert :ok ==
               ArtifactCleanupWorker.perform(%Oban.Job{args: %{"session_id" => unknown}})
    end
  end
end
