defmodule James.Integration.CronAwayTest do
  @moduledoc """
  E2E integration tests for cron scheduling and away-summary detection:
    1. Schedule a cron task via CronTools.execute/3 → verify task exists
    2. Manually fire scheduler tick → verify user message injected
    3. cron_list returns active tasks
    4. cron_delete removes the task
    5. AwayDetector.on_resume/1 returns {:inject, summary} for session
       with old updated_at and completed background tasks
  """

  use James.DataCase

  alias James.{Accounts, Cron, Sessions, Tasks}
  alias James.Agents.Tools.CronTools
  alias James.Cron.Scheduler
  alias James.Sessions.AwayDetector

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_email, do: "cron_away_#{System.unique_integer([:positive])}@example.com"

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: unique_email()})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Cron Away Session"})
    session
  end

  defp tool_state(session), do: %{session_id: session.id}

  defp future_next_fire_at do
    DateTime.add(DateTime.utc_now(), 300, :second)
  end

  defp past_fire_at do
    DateTime.add(DateTime.utc_now(), -60, :second)
  end

  # ---------------------------------------------------------------------------
  # 1. Schedule cron task via CronTools.execute("cron_schedule", ...) → verify
  # ---------------------------------------------------------------------------

  describe "cron_schedule via CronTools" do
    test "scheduling a task creates it in the DB and returns confirmation" do
      user = create_user()
      session = create_session(user)

      assert {:ok, msg} =
               CronTools.execute(
                 "cron_schedule",
                 %{"cron" => "*/15 * * * *", "prompt" => "integration check"},
                 tool_state(session)
               )

      assert msg =~ "Cron task scheduled"
      assert msg =~ "ID:"
      assert msg =~ "next fire at:"

      tasks = Cron.list_cron_tasks_for_session(session.id)
      assert length(tasks) == 1

      task = hd(tasks)
      assert task.prompt == "integration check"
      assert task.cron_expression == "*/15 * * * *"
      assert task.enabled == true
    end

    test "invalid cron expression returns error and does not create task" do
      user = create_user()
      session = create_session(user)

      assert {:error, msg} =
               CronTools.execute(
                 "cron_schedule",
                 %{"cron" => "not-valid", "prompt" => "bad cron"},
                 tool_state(session)
               )

      assert msg =~ "Invalid cron expression"
      assert Cron.list_cron_tasks_for_session(session.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Manually fire scheduler tick → verify user message injected
  # ---------------------------------------------------------------------------

  describe "scheduler tick fires due tasks" do
    test "due cron task injects user message into session" do
      user = create_user()
      session = create_session(user)

      # Create a task that is already due
      {:ok, task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "*/5 * * * *",
          prompt: "integration status check",
          next_fire_at: past_fire_at()
        })

      # Start a scheduler with a very short tick interval
      {:ok, pid} = GenServer.start_link(Scheduler, [tick_interval: 50], [])

      # Wait for at least one tick
      Process.sleep(150)
      GenServer.stop(pid)

      messages = Sessions.list_messages(session.id)
      user_msgs = Enum.filter(messages, &(&1.role == "user"))

      assert Enum.any?(user_msgs, fn m -> m.content == task.prompt end),
             "Expected cron prompt to be injected as a user message"
    end

    test "tick updates last_fired_at and advances next_fire_at for recurring tasks" do
      user = create_user()
      session = create_session(user)

      {:ok, task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "*/5 * * * *",
          prompt: "recurring check",
          next_fire_at: past_fire_at(),
          recurring: true
        })

      {:ok, pid} = GenServer.start_link(Scheduler, [tick_interval: 50], [])
      Process.sleep(150)
      GenServer.stop(pid)

      updated = Cron.get_cron_task(task.id)
      assert updated.last_fired_at != nil
      assert DateTime.compare(updated.next_fire_at, task.next_fire_at) == :gt
    end
  end

  # ---------------------------------------------------------------------------
  # 3. cron_list returns the active task
  # ---------------------------------------------------------------------------

  describe "cron_list via CronTools" do
    test "returns active tasks after scheduling" do
      user = create_user()
      session = create_session(user)

      {:ok, task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "0 8 * * *",
          prompt: "morning briefing",
          next_fire_at: future_next_fire_at()
        })

      assert {:ok, msg} = CronTools.execute("cron_list", %{}, tool_state(session))
      assert msg =~ task.id
      assert msg =~ "morning briefing"
    end

    test "returns empty list message when no tasks scheduled" do
      user = create_user()
      session = create_session(user)

      assert {:ok, msg} = CronTools.execute("cron_list", %{}, tool_state(session))
      assert msg =~ "No cron tasks"
    end
  end

  # ---------------------------------------------------------------------------
  # 4. cron_delete removes the task → verify gone
  # ---------------------------------------------------------------------------

  describe "cron_delete via CronTools" do
    test "deletes the task and confirms removal" do
      user = create_user()
      session = create_session(user)

      {:ok, task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "*/10 * * * *",
          prompt: "to be deleted",
          next_fire_at: future_next_fire_at()
        })

      assert {:ok, msg} =
               CronTools.execute("cron_delete", %{"id" => task.id}, tool_state(session))

      assert msg =~ task.id
      assert Cron.get_cron_task(task.id) == nil

      # cron_list should now show no tasks
      assert {:ok, list_msg} = CronTools.execute("cron_list", %{}, tool_state(session))
      assert list_msg =~ "No cron tasks"
    end

    test "deleting non-existent task returns error" do
      user = create_user()
      session = create_session(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, msg} =
               CronTools.execute("cron_delete", %{"id" => fake_id}, tool_state(session))

      assert msg =~ "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # 5. AwayDetector.on_resume/1 returns {:inject, summary} for idle session
  #    with completed tasks
  # ---------------------------------------------------------------------------

  describe "AwayDetector.on_resume/1" do
    test "returns {:inject, summary} for session idle > threshold with completed tasks" do
      user = create_user()
      session = create_session(user)

      # Create a completed task
      {:ok, task} =
        Tasks.create_task(%{
          session_id: session.id,
          description: "Background data sync",
          status: "pending"
        })

      # Mark task as completed (sets completed_at to now)
      {:ok, _completed_task} = Tasks.update_task_status(task, "completed")

      # Use a "now" that is 10 minutes after session.inserted_at to simulate idleness
      future_now = DateTime.add(session.inserted_at, 10 * 60, :second)

      result = AwayDetector.on_resume(session.id, threshold_minutes: 5, now: future_now)
      assert {:inject, summary} = result
      assert summary =~ "While you were away"
      assert summary =~ "Background data sync"
    end

    test "returns :no_summary_needed when session was active recently" do
      user = create_user()
      session = create_session(user)

      {:ok, task} = Tasks.create_task(%{session_id: session.id, description: "Quick task"})
      {:ok, _} = Tasks.update_task_status(task, "completed")

      # "now" is only 1 minute after session creation — below threshold
      recent_now = DateTime.add(session.inserted_at, 60, :second)

      result = AwayDetector.on_resume(session.id, threshold_minutes: 5, now: recent_now)
      assert result == :no_summary_needed
    end

    test "returns :no_summary_needed when no completed tasks exist" do
      user = create_user()
      session = create_session(user)

      # Only a pending task — not completed
      {:ok, _} = Tasks.create_task(%{session_id: session.id, description: "Still running"})

      future_now = DateTime.add(session.inserted_at, 20 * 60, :second)

      result = AwayDetector.on_resume(session.id, threshold_minutes: 5, now: future_now)
      assert result == :no_summary_needed
    end

    test "returns :no_summary_needed for non-existent session" do
      fake_id = Ecto.UUID.generate()
      assert AwayDetector.on_resume(fake_id) == :no_summary_needed
    end

    test "build_away_summary formats multiple tasks correctly" do
      tasks = [
        %{description: "Fetch emails", status: "completed"},
        %{description: "Run diagnostics", status: "completed"}
      ]

      summary = AwayDetector.build_away_summary(tasks)
      assert summary =~ "While you were away"
      assert summary =~ "Fetch emails"
      assert summary =~ "Run diagnostics"
      assert summary =~ "(completed)"
    end
  end
end
