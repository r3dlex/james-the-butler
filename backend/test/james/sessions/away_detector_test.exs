defmodule James.Sessions.AwayDetectorTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Sessions.AwayDetector

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: "away_#{System.unique_integer()}@example.com"})
    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "away-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9903"
      })

    host
  end

  defp create_session(user, host) do
    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Away Session"})

    session
  end

  defp backdate_session(session, minutes_ago) do
    past = DateTime.add(DateTime.utc_now(), -minutes_ago * 60, :second)

    James.Repo.update_all(
      from(s in James.Sessions.Session, where: s.id == ^session.id),
      set: [last_used_at: past]
    )

    James.Repo.get(James.Sessions.Session, session.id)
  end

  defp create_completed_task(session, description \\ "Background task") do
    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: description,
        status: "pending",
        risk_level: "read_only",
        host_id: session.host_id
      })

    {:ok, task} = Tasks.update_task_status(task, "completed")
    task
  end

  defp add_planner_away_message(session) do
    {:ok, msg} =
      Sessions.create_message(%{
        session_id: session.id,
        role: "planner",
        content:
          "While you were away, the following background tasks completed:\n\n- Task A (completed)"
      })

    msg
  end

  describe "on_resume/2" do
    test "returns :no_summary_needed when session was active recently (< 5 min)" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)

      # Session is fresh — last_used_at defaults to now (within seconds)
      assert :no_summary_needed == AwayDetector.on_resume(session.id)
    end

    test "returns :no_summary_needed when idle but no background tasks completed" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      _session = backdate_session(session, 10)

      assert :no_summary_needed == AwayDetector.on_resume(session.id)
    end

    test "returns {:inject, summary} when idle > 5 min AND background tasks completed" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      _session = backdate_session(session, 10)
      _task = create_completed_task(session)

      result = AwayDetector.on_resume(session.id)
      assert {:inject, _summary} = result
    end

    test "summary includes task names and statuses" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      _session = backdate_session(session, 10)
      _task = create_completed_task(session, "Summarise research papers")

      {:inject, summary} = AwayDetector.on_resume(session.id)
      assert summary =~ "Summarise research papers"
      assert summary =~ "completed"
    end

    test "respects configurable threshold — skips when below configured minutes" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      # Backdate by 2 minutes; use threshold of 1 minute
      _session = backdate_session(session, 2)
      _task = create_completed_task(session)

      # With 1-minute threshold, 2 minutes idle should trigger summary
      result = AwayDetector.on_resume(session.id, threshold_minutes: 1)
      assert {:inject, _} = result
    end

    test "returns :no_summary_needed when idle < configured threshold" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      # Backdate by 2 minutes; use threshold of 10 minutes
      _session = backdate_session(session, 2)
      _task = create_completed_task(session)

      result = AwayDetector.on_resume(session.id, threshold_minutes: 10)
      assert :no_summary_needed == result
    end

    test "returns :no_summary_needed if away summary already injected since last user message" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      _session = backdate_session(session, 10)
      _task = create_completed_task(session)

      # First call — summary injected
      {:inject, _} = AwayDetector.on_resume(session.id)

      # Simulate the channel storing the injected summary as a planner message
      _away_msg = add_planner_away_message(session)

      # Second call — should not inject again
      assert :no_summary_needed == AwayDetector.on_resume(session.id)
    end

    test "returns :no_summary_needed for non-existent session_id" do
      assert :no_summary_needed == AwayDetector.on_resume(Ecto.UUID.generate())
    end
  end

  describe "build_away_summary/2" do
    test "includes task descriptions in the output" do
      tasks = [
        %{description: "Fetch pricing data", status: "completed"},
        %{description: "Send nightly report", status: "completed"}
      ]

      summary = AwayDetector.build_away_summary(tasks)
      assert summary =~ "Fetch pricing data"
      assert summary =~ "Send nightly report"
    end

    test "includes task statuses in the output" do
      tasks = [%{description: "Run migrations", status: "completed"}]

      summary = AwayDetector.build_away_summary(tasks)
      assert summary =~ "completed"
    end

    test "includes 'While you were away' header" do
      tasks = [%{description: "Some task", status: "completed"}]

      summary = AwayDetector.build_away_summary(tasks)
      assert summary =~ "While you were away"
    end
  end
end
