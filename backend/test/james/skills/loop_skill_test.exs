defmodule James.Skills.LoopSkillTest do
  use James.DataCase

  alias James.{Accounts, Cron, Sessions}
  alias James.Skills.LoopSkill

  defp create_user(email) do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Loop Test Session"})
    session
  end

  defp state(session_id, prompt \\ "Check email") do
    %{session_id: session_id, prompt: prompt}
  end

  describe "execute/2 — interval parsing" do
    test "5m creates a cron task with */5 * * * *" do
      user = create_user("loop_5m@example.com")
      session = create_session(user)

      assert {:ok, msg} = LoopSkill.execute("5m", state(session.id))
      assert msg =~ "*/5 * * * *"

      tasks = Cron.list_cron_tasks_for_session(session.id)
      assert length(tasks) == 1
      assert hd(tasks).cron_expression == "*/5 * * * *"
    end

    test "1h creates a cron task with 0 */1 * * *" do
      user = create_user("loop_1h@example.com")
      session = create_session(user)

      assert {:ok, msg} = LoopSkill.execute("1h", state(session.id))
      assert msg =~ "0 */1 * * *"

      tasks = Cron.list_cron_tasks_for_session(session.id)
      assert length(tasks) == 1
      assert hd(tasks).cron_expression == "0 */1 * * *"
    end

    test "30s creates a cron task (collapsed to every minute)" do
      user = create_user("loop_30s@example.com")
      session = create_session(user)

      assert {:ok, _msg} = LoopSkill.execute("30s", state(session.id))

      tasks = Cron.list_cron_tasks_for_session(session.id)
      assert length(tasks) == 1
      assert hd(tasks).cron_expression == "* * * * *"
    end

    test "10m creates a cron task with */10 * * * *" do
      user = create_user("loop_10m@example.com")
      session = create_session(user)

      assert {:ok, _msg} = LoopSkill.execute("10m", state(session.id))

      tasks = Cron.list_cron_tasks_for_session(session.id)
      assert hd(tasks).cron_expression == "*/10 * * * *"
    end

    test "invalid interval returns error message" do
      user = create_user("loop_invalid@example.com")
      session = create_session(user)

      assert {:error, msg} = LoopSkill.execute("foobar", state(session.id))
      assert msg =~ "Invalid interval"
    end
  end

  describe "execute/2 — stop" do
    test "stop deletes cron tasks for the session" do
      user = create_user("loop_stop@example.com")
      session = create_session(user)

      {:ok, _} = LoopSkill.execute("5m", state(session.id, "Prompt A"))
      {:ok, _} = LoopSkill.execute("1h", state(session.id, "Prompt B"))

      assert length(Cron.list_cron_tasks_for_session(session.id)) == 2

      assert {:ok, msg} = LoopSkill.execute("stop", state(session.id))
      assert msg =~ "Stopped 2 loop task"

      assert Cron.list_cron_tasks_for_session(session.id) == []
    end

    test "stop with no tasks returns a human-readable message" do
      user = create_user("loop_stop_empty@example.com")
      session = create_session(user)

      assert {:ok, msg} = LoopSkill.execute("stop", state(session.id))
      assert is_binary(msg)
    end
  end

  describe "execute/2 — list" do
    test "list returns current tasks" do
      user = create_user("loop_list@example.com")
      session = create_session(user)

      {:ok, _} = LoopSkill.execute("5m", state(session.id, "Check something"))

      assert {:ok, msg} = LoopSkill.execute("list", state(session.id))
      assert msg =~ "*/5 * * * *"
    end

    test "list with no tasks returns human-readable message" do
      user = create_user("loop_list_empty@example.com")
      session = create_session(user)

      assert {:ok, msg} = LoopSkill.execute("list", state(session.id))
      assert msg =~ "No cron tasks"
    end
  end

  describe "execute/2 — human-readable confirmation" do
    test "returns human-readable confirmation string" do
      user = create_user("loop_confirm@example.com")
      session = create_session(user)

      assert {:ok, msg} = LoopSkill.execute("5m", state(session.id))
      assert is_binary(msg)
      assert msg =~ "5m"
    end
  end
end
