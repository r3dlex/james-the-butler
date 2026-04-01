defmodule James.ArtifactsTest do
  use James.DataCase

  alias James.{Accounts, Artifacts, Hosts, Sessions, Tasks}

  defp setup_context do
    {:ok, user} =
      Accounts.create_user(%{email: "artifacts_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "art-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9600"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Art Session"})

    {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "test task"})
    %{user: user, session: session, task: task}
  end

  describe "create_artifact/1" do
    test "creates with valid attrs" do
      %{session: session} = setup_context()

      {:ok, artifact} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          type: "file",
          path: "/tmp/output.txt"
        })

      assert artifact.session_id == session.id
      assert artifact.type == "file"
      assert artifact.path == "/tmp/output.txt"
      assert artifact.is_deliverable == false
      assert is_nil(artifact.cleaned_at)
    end

    test "requires session_id" do
      assert {:error, changeset} = Artifacts.create_artifact(%{type: "file"})
      assert %{session_id: [_ | _]} = errors_on(changeset)
    end

    test "requires valid type" do
      %{session: session} = setup_context()

      assert {:error, changeset} =
               Artifacts.create_artifact(%{session_id: session.id, type: "unknown"})

      assert %{type: [_ | _]} = errors_on(changeset)
    end

    test "accepts is_deliverable flag" do
      %{session: session, task: task} = setup_context()

      {:ok, artifact} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          task_id: task.id,
          type: "document",
          is_deliverable: true
        })

      assert artifact.is_deliverable == true
    end
  end

  describe "list_artifacts/1" do
    test "lists by session_id" do
      %{session: session} = setup_context()

      {:ok, _} = Artifacts.create_artifact(%{session_id: session.id, type: "file"})
      {:ok, _} = Artifacts.create_artifact(%{session_id: session.id, type: "image"})

      results = Artifacts.list_artifacts(session_id: session.id)
      assert length(results) == 2
    end

    test "filters by task_id" do
      %{session: session, task: task} = setup_context()

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, task_id: task.id, type: "file"})

      {:ok, _} = Artifacts.create_artifact(%{session_id: session.id, type: "file"})

      results = Artifacts.list_artifacts(task_id: task.id)
      assert length(results) == 1
    end

    test "filters deliverable_only" do
      %{session: session} = setup_context()

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, type: "file", is_deliverable: true})

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, type: "file", is_deliverable: false})

      results = Artifacts.list_artifacts(session_id: session.id, deliverable_only: true)
      assert length(results) == 1
      assert hd(results).is_deliverable == true
    end

    test "filters uncleaned_only" do
      %{session: session} = setup_context()

      {:ok, a1} = Artifacts.create_artifact(%{session_id: session.id, type: "file"})
      {:ok, _} = Artifacts.create_artifact(%{session_id: session.id, type: "file"})

      Artifacts.mark_cleaned(a1)

      results = Artifacts.list_artifacts(session_id: session.id, uncleaned_only: true)
      assert length(results) == 1
    end
  end

  describe "get_artifact/1 and get_artifact!/1" do
    test "returns artifact by id" do
      %{session: session} = setup_context()
      {:ok, artifact} = Artifacts.create_artifact(%{session_id: session.id, type: "code"})

      assert Artifacts.get_artifact(artifact.id).id == artifact.id
      assert Artifacts.get_artifact!(artifact.id).id == artifact.id
    end

    test "get_artifact returns nil for unknown id" do
      assert is_nil(Artifacts.get_artifact(Ecto.UUID.generate()))
    end

    test "get_artifact! raises for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Artifacts.get_artifact!(Ecto.UUID.generate())
      end
    end
  end

  describe "mark_cleaned/1" do
    test "sets cleaned_at timestamp" do
      %{session: session} = setup_context()
      {:ok, artifact} = Artifacts.create_artifact(%{session_id: session.id, type: "file"})

      {:ok, updated} = Artifacts.mark_cleaned(artifact)
      assert not is_nil(updated.cleaned_at)
    end
  end

  describe "clean_task_artifacts/1" do
    test "marks non-deliverable task artifacts as cleaned" do
      %{session: session, task: task} = setup_context()

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, task_id: task.id, type: "file"})

      {:ok, _} =
        Artifacts.create_artifact(%{session_id: session.id, task_id: task.id, type: "file"})

      {:ok, _} =
        Artifacts.create_artifact(%{
          session_id: session.id,
          task_id: task.id,
          type: "document",
          is_deliverable: true
        })

      {:ok, count} = Artifacts.clean_task_artifacts(task.id)
      assert count == 2

      remaining = Artifacts.list_artifacts(task_id: task.id, uncleaned_only: true)
      assert length(remaining) == 1
      assert hd(remaining).is_deliverable == true
    end

    test "returns 0 when nothing to clean" do
      {:ok, count} = Artifacts.clean_task_artifacts(Ecto.UUID.generate())
      assert count == 0
    end
  end
end
