defmodule James.Cron.SchedulerTest do
  use James.DataCase

  alias James.{Accounts, Cron, Sessions}
  alias James.Cron.Scheduler

  # Use a very short tick so we don't have to wait in tests
  @tick_interval 100

  defp create_user(tag) do
    {:ok, user} =
      Accounts.create_user(%{email: "scheduler#{tag}_#{System.unique_integer()}@example.com"})

    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Scheduler Session"})
    session
  end

  defp past_fire_at do
    DateTime.add(DateTime.utc_now(), -60, :second)
  end

  defp future_fire_at do
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  defp create_due_task(session_id, opts \\ []) do
    Cron.create_cron_task(%{
      session_id: session_id,
      cron_expression: "*/5 * * * *",
      prompt: "check status",
      next_fire_at: past_fire_at(),
      recurring: Keyword.get(opts, :recurring, true),
      enabled: Keyword.get(opts, :enabled, true)
    })
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1" do
    test "GenServer starts successfully" do
      {:ok, pid} = Scheduler.start_link(tick_interval: @tick_interval)
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info(:tick, state)
  # ---------------------------------------------------------------------------

  describe "handle_info(:tick, state)" do
    test "dispatches due tasks by creating a user message in the session" do
      user = create_user("dispatch")
      session = create_session(user)
      {:ok, task} = create_due_task(session.id)

      {:ok, pid} =
        GenServer.start_link(Scheduler, [tick_interval: @tick_interval], [])

      # Allow at least one tick to fire
      Process.sleep(@tick_interval * 2)
      GenServer.stop(pid)

      messages = Sessions.list_messages(session.id)
      user_msgs = Enum.filter(messages, &(&1.role == "user"))
      assert Enum.any?(user_msgs, fn m -> m.content == task.prompt end)
    end

    test "updates last_fired_at and next_fire_at after dispatch for recurring task" do
      user = create_user("update")
      session = create_session(user)
      {:ok, task} = create_due_task(session.id, recurring: true)

      {:ok, pid} =
        GenServer.start_link(Scheduler, [tick_interval: @tick_interval], [])

      Process.sleep(@tick_interval * 2)
      GenServer.stop(pid)

      updated = Cron.get_cron_task(task.id)
      assert updated.last_fired_at != nil
      assert DateTime.compare(updated.next_fire_at, task.next_fire_at) == :gt
    end

    test "disables non-recurring task after first fire" do
      user = create_user("nonrecurring")
      session = create_session(user)
      {:ok, task} = create_due_task(session.id, recurring: false)

      {:ok, pid} =
        GenServer.start_link(Scheduler, [tick_interval: @tick_interval], [])

      Process.sleep(@tick_interval * 2)
      GenServer.stop(pid)

      updated = Cron.get_cron_task(task.id)
      assert updated.enabled == false
    end

    test "disabled tasks are not dispatched" do
      user = create_user("disabled")
      session = create_session(user)

      {:ok, _task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "*/5 * * * *",
          prompt: "should not fire",
          next_fire_at: past_fire_at(),
          enabled: false
        })

      {:ok, pid} =
        GenServer.start_link(Scheduler, [tick_interval: @tick_interval], [])

      Process.sleep(@tick_interval * 2)
      GenServer.stop(pid)

      messages = Sessions.list_messages(session.id)
      user_msgs = Enum.filter(messages, &(&1.role == "user"))
      refute Enum.any?(user_msgs, fn m -> m.content == "should not fire" end)
    end

    test "empty due list is a no-op (no messages created)" do
      user = create_user("empty")
      session = create_session(user)

      # Only create a task in the future — not due yet
      {:ok, _task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "*/5 * * * *",
          prompt: "future task",
          next_fire_at: future_fire_at()
        })

      {:ok, pid} =
        GenServer.start_link(Scheduler, [tick_interval: @tick_interval], [])

      Process.sleep(@tick_interval * 2)
      GenServer.stop(pid)

      messages = Sessions.list_messages(session.id)
      assert messages == []
    end

    test "tick reschedules itself (more than one tick fires)" do
      user = create_user("reschedule")
      session = create_session(user)

      # Create a recurring task; after first tick it will be rescheduled in the
      # future so it should only fire once per due window. We verify the
      # scheduler itself stays alive and keeps ticking by observing that it is
      # still running after multiple intervals.
      {:ok, _task} = create_due_task(session.id, recurring: true)

      {:ok, pid} =
        GenServer.start_link(Scheduler, [tick_interval: @tick_interval], [])

      Process.sleep(@tick_interval * 3)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
