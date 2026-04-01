defmodule James.CronTest do
  use James.DataCase

  alias James.{Accounts, Cron, Sessions}
  alias James.Cron.CronTask

  defp create_user(email \\ "cron_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Cron Session"})
    session
  end

  defp valid_attrs(session_id) do
    next = DateTime.add(DateTime.utc_now(), 300, :second)

    %{
      session_id: session_id,
      cron_expression: "*/5 * * * *",
      prompt: "Run the daily report",
      next_fire_at: next
    }
  end

  describe "create_cron_task/1" do
    test "succeeds with valid attrs" do
      user = create_user()
      session = create_session(user)
      assert {:ok, %CronTask{} = task} = Cron.create_cron_task(valid_attrs(session.id))
      assert task.session_id == session.id
      assert task.cron_expression == "*/5 * * * *"
      assert task.prompt == "Run the daily report"
      assert task.enabled == true
      assert task.recurring == true
    end

    test "rejects invalid cron expression" do
      user = create_user("cron_invalid@example.com")
      session = create_session(user)

      attrs = valid_attrs(session.id) |> Map.put(:cron_expression, "not-a-cron")
      assert {:error, changeset} = Cron.create_cron_task(attrs)
      assert %{cron_expression: [_]} = errors_on(changeset)
    end

    test "rejects missing session_id" do
      next = DateTime.add(DateTime.utc_now(), 300, :second)

      attrs = %{
        cron_expression: "*/5 * * * *",
        prompt: "No session",
        next_fire_at: next
      }

      assert {:error, changeset} = Cron.create_cron_task(attrs)
      assert %{session_id: [_]} = errors_on(changeset)
    end
  end

  describe "list_cron_tasks/1" do
    test "filters by session_id" do
      user = create_user("cron_list@example.com")
      session1 = create_session(user)
      session2 = create_session(user)
      {:ok, _} = Cron.create_cron_task(valid_attrs(session1.id))
      {:ok, _} = Cron.create_cron_task(valid_attrs(session2.id))

      tasks = Cron.list_cron_tasks(session1.id)
      assert length(tasks) == 1
      assert hd(tasks).session_id == session1.id
    end
  end

  describe "list_due_tasks/0" do
    test "returns tasks where next_fire_at <= now and enabled == true" do
      user = create_user("cron_due@example.com")
      session = create_session(user)
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      attrs = valid_attrs(session.id) |> Map.put(:next_fire_at, past)
      {:ok, task} = Cron.create_cron_task(attrs)

      due = Cron.list_due_tasks()
      ids = Enum.map(due, & &1.id)
      assert task.id in ids
    end

    test "excludes disabled tasks" do
      user = create_user("cron_disabled@example.com")
      session = create_session(user)
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      attrs = valid_attrs(session.id) |> Map.put(:next_fire_at, past) |> Map.put(:enabled, false)
      {:ok, task} = Cron.create_cron_task(attrs)

      due = Cron.list_due_tasks()
      ids = Enum.map(due, & &1.id)
      refute task.id in ids
    end

    test "excludes tasks with expires_at in the past" do
      user = create_user("cron_expired@example.com")
      session = create_session(user)
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      expired = DateTime.add(DateTime.utc_now(), -3600, :second)

      attrs =
        valid_attrs(session.id)
        |> Map.put(:next_fire_at, past)
        |> Map.put(:expires_at, expired)

      {:ok, task} = Cron.create_cron_task(attrs)

      due = Cron.list_due_tasks()
      ids = Enum.map(due, & &1.id)
      refute task.id in ids
    end
  end

  describe "update_after_fire/1" do
    test "sets last_fired_at and computes next_fire_at for recurring task" do
      user = create_user("cron_fire@example.com")
      session = create_session(user)
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      attrs = valid_attrs(session.id) |> Map.put(:next_fire_at, past)
      {:ok, task} = Cron.create_cron_task(attrs)

      assert {:ok, updated} = Cron.update_after_fire(task)
      assert updated.last_fired_at != nil
      assert DateTime.compare(updated.next_fire_at, past) == :gt
      assert updated.enabled == true
    end

    test "disables non-recurring task after fire" do
      user = create_user("cron_once@example.com")
      session = create_session(user)
      past = DateTime.add(DateTime.utc_now(), -60, :second)

      attrs =
        valid_attrs(session.id)
        |> Map.put(:next_fire_at, past)
        |> Map.put(:recurring, false)

      {:ok, task} = Cron.create_cron_task(attrs)

      assert {:ok, updated} = Cron.update_after_fire(task)
      assert updated.enabled == false
    end
  end

  describe "delete_cron_task/1" do
    test "removes the task" do
      user = create_user("cron_delete@example.com")
      session = create_session(user)
      {:ok, task} = Cron.create_cron_task(valid_attrs(session.id))

      assert {:ok, _} = Cron.delete_cron_task(task)
      assert Cron.get_cron_task(task.id) == nil
    end
  end

  describe "disable_cron_task/1" do
    test "sets enabled to false" do
      user = create_user("cron_dis@example.com")
      session = create_session(user)
      {:ok, task} = Cron.create_cron_task(valid_attrs(session.id))

      assert {:ok, updated} = Cron.disable_cron_task(task)
      assert updated.enabled == false
    end
  end

  describe "list_cron_tasks_for_session/1" do
    test "returns only that session's tasks" do
      user = create_user("cron_sess@example.com")
      session1 = create_session(user)
      session2 = create_session(user)
      {:ok, _} = Cron.create_cron_task(valid_attrs(session1.id))
      {:ok, _} = Cron.create_cron_task(valid_attrs(session1.id))
      {:ok, _} = Cron.create_cron_task(valid_attrs(session2.id))

      tasks = Cron.list_cron_tasks_for_session(session1.id)
      assert length(tasks) == 2
      assert Enum.all?(tasks, &(&1.session_id == session1.id))
    end
  end

  describe "compute_expires_at/1" do
    test "adds max_age_days to inserted_at" do
      user = create_user("cron_exp@example.com")
      session = create_session(user)
      attrs = valid_attrs(session.id) |> Map.put(:max_age_days, 7)
      {:ok, task} = Cron.create_cron_task(attrs)

      expires_at = Cron.compute_expires_at(task)
      expected = DateTime.add(task.inserted_at, 7 * 24 * 3600, :second)
      # Allow 1 second tolerance
      assert abs(DateTime.diff(expires_at, expected)) <= 1
    end
  end
end
