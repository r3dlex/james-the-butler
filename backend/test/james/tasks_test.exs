defmodule James.TasksTest do
  use James.DataCase

  alias James.{Accounts, Sessions, Tasks}

  defp create_user(email \\ "task_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Task Session"})
    session
  end

  defp create_task(session, attrs \\ %{}) do
    {:ok, task} = Tasks.create_task(Map.merge(%{session_id: session.id}, attrs))
    task
  end

  describe "create_task/1" do
    test "creates a task with session_id" do
      user = create_user()
      session = create_session(user)
      assert {:ok, task} = Tasks.create_task(%{session_id: session.id})
      assert task.session_id == session.id
    end

    test "defaults status to pending" do
      user = create_user("task_default@example.com")
      session = create_session(user)
      {:ok, task} = Tasks.create_task(%{session_id: session.id})
      assert task.status == "pending"
    end

    test "defaults risk_level to read_only" do
      user = create_user("task_risk@example.com")
      session = create_session(user)
      {:ok, task} = Tasks.create_task(%{session_id: session.id})
      assert task.risk_level == "read_only"
    end

    test "creates task with description" do
      user = create_user("task_desc@example.com")
      session = create_session(user)
      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "Do something"})
      assert task.description == "Do something"
    end

    test "fails when session_id is missing" do
      assert {:error, changeset} = Tasks.create_task(%{description: "Orphan"})
      assert %{session_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid risk_level" do
      user = create_user("task_bad_risk@example.com")
      session = create_session(user)

      assert {:error, changeset} =
               Tasks.create_task(%{session_id: session.id, risk_level: "extreme"})

      assert %{risk_level: [_]} = errors_on(changeset)
    end

    test "rejects invalid status" do
      user = create_user("task_bad_status@example.com")
      session = create_session(user)

      assert {:error, changeset} =
               Tasks.create_task(%{session_id: session.id, status: "flying"})

      assert %{status: [_]} = errors_on(changeset)
    end
  end

  describe "get_task/1" do
    test "returns task by id" do
      user = create_user("get_task@example.com")
      session = create_session(user)
      task = create_task(session)
      assert found = Tasks.get_task(task.id)
      assert found.id == task.id
    end

    test "returns nil for unknown id" do
      assert Tasks.get_task(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_tasks/1" do
    test "filters by session_id" do
      user = create_user("list_tasks@example.com")
      session1 = create_session(user)
      session2 = create_session(user)
      create_task(session1)
      create_task(session2)
      tasks = Tasks.list_tasks(session_id: session1.id)
      assert length(tasks) == 1
      assert hd(tasks).session_id == session1.id
    end

    test "filters by status" do
      user = create_user("list_task_status@example.com")
      session = create_session(user)
      create_task(session, %{status: "pending"})
      create_task(session, %{status: "completed"})
      pending = Tasks.list_tasks(session_id: session.id, status: "pending")
      assert length(pending) == 1
      assert hd(pending).status == "pending"
    end

    test "filters by risk_level" do
      user = create_user("list_task_risk@example.com")
      session = create_session(user)
      create_task(session, %{risk_level: "read_only"})
      create_task(session, %{risk_level: "destructive"})
      tasks = Tasks.list_tasks(session_id: session.id, risk_level: "destructive")
      assert length(tasks) == 1
      assert hd(tasks).risk_level == "destructive"
    end

    test "returns all tasks when no filters" do
      user = create_user("list_all_tasks@example.com")
      session = create_session(user)
      create_task(session)
      create_task(session)
      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) == 2
    end
  end

  describe "update_task/2" do
    test "updates status" do
      user = create_user("update_task@example.com")
      session = create_session(user)
      task = create_task(session)
      assert {:ok, updated} = Tasks.update_task_status(task, "completed")
      assert updated.status == "completed"
    end

    test "sets completed_at when status is completed" do
      user = create_user("complete_task@example.com")
      session = create_session(user)
      task = create_task(session)
      {:ok, updated} = Tasks.update_task_status(task, "completed")
      assert updated.completed_at != nil
    end

    test "does not set completed_at for other statuses" do
      user = create_user("running_task@example.com")
      session = create_session(user)
      task = create_task(session)
      {:ok, updated} = Tasks.update_task_status(task, "running")
      assert updated.completed_at == nil
    end
  end

  describe "approve_task/1" do
    test "sets status to approved" do
      user = create_user("approve_task@example.com")
      session = create_session(user)
      task = create_task(session)
      assert {:ok, approved} = Tasks.approve_task(task)
      assert approved.status == "approved"
    end
  end

  describe "reject_task/1" do
    test "sets status to rejected" do
      user = create_user("reject_task@example.com")
      session = create_session(user)
      task = create_task(session)
      assert {:ok, rejected} = Tasks.reject_task(task)
      assert rejected.status == "rejected"
    end
  end
end
