defmodule James.Agents.Tools.CronToolsTest do
  use James.DataCase

  alias James.{Accounts, Cron, Sessions}
  alias James.Agents.Tools.CronTools

  defp create_session do
    {:ok, user} =
      Accounts.create_user(%{email: "cron_tools_#{System.unique_integer()}@example.com"})

    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "CronTools Session"})
    session
  end

  defp tool_state(session), do: %{session_id: session.id}

  defp future_next_fire_at do
    DateTime.add(DateTime.utc_now(), 300, :second)
  end

  # ---------------------------------------------------------------------------
  # cron_schedule
  # ---------------------------------------------------------------------------

  describe "execute(\"cron_schedule\", ...)" do
    test "creates a cron task and returns confirmation with ID and next_fire_at" do
      session = create_session()

      assert {:ok, msg} =
               CronTools.execute(
                 "cron_schedule",
                 %{"cron" => "*/5 * * * *", "prompt" => "check status"},
                 tool_state(session)
               )

      assert msg =~ "Cron task scheduled"
      assert msg =~ "ID:"
      assert msg =~ "next fire at:"

      tasks = Cron.list_cron_tasks_for_session(session.id)
      assert length(tasks) == 1
      assert hd(tasks).prompt == "check status"
      assert hd(tasks).cron_expression == "*/5 * * * *"
    end

    test "invalid cron expression returns error message" do
      session = create_session()

      assert {:error, msg} =
               CronTools.execute(
                 "cron_schedule",
                 %{"cron" => "not-a-cron", "prompt" => "check status"},
                 tool_state(session)
               )

      assert msg =~ "Invalid cron expression"
    end
  end

  # ---------------------------------------------------------------------------
  # cron_delete
  # ---------------------------------------------------------------------------

  describe "execute(\"cron_delete\", ...)" do
    test "removes the task and returns confirmation" do
      session = create_session()

      {:ok, task} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "0 * * * *",
          prompt: "hourly check",
          next_fire_at: future_next_fire_at()
        })

      assert {:ok, msg} =
               CronTools.execute(
                 "cron_delete",
                 %{"id" => task.id},
                 tool_state(session)
               )

      assert msg =~ task.id
      assert Cron.get_cron_task(task.id) == nil
    end

    test "non-existent ID returns error" do
      session = create_session()
      fake_id = Ecto.UUID.generate()

      assert {:error, msg} =
               CronTools.execute(
                 "cron_delete",
                 %{"id" => fake_id},
                 tool_state(session)
               )

      assert msg =~ "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # cron_list
  # ---------------------------------------------------------------------------

  describe "execute(\"cron_list\", ...)" do
    test "returns list of active tasks for the session" do
      session = create_session()

      {:ok, task1} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "*/5 * * * *",
          prompt: "first prompt",
          next_fire_at: future_next_fire_at()
        })

      {:ok, _task2} =
        Cron.create_cron_task(%{
          session_id: session.id,
          cron_expression: "0 9 * * *",
          prompt: "second prompt",
          next_fire_at: future_next_fire_at()
        })

      assert {:ok, msg} = CronTools.execute("cron_list", %{}, tool_state(session))
      assert msg =~ task1.id
      assert msg =~ "first prompt"
      assert msg =~ "second prompt"
    end

    test "returns empty list message when no tasks exist" do
      session = create_session()

      assert {:ok, msg} = CronTools.execute("cron_list", %{}, tool_state(session))
      assert msg =~ "No cron tasks"
    end
  end

  # ---------------------------------------------------------------------------
  # tool_definitions/0
  # ---------------------------------------------------------------------------

  describe "tool_definitions/0" do
    test "returns exactly 3 tool definition maps" do
      defs = CronTools.tool_definitions()
      assert length(defs) == 3
    end

    test "each definition has :name, :description, and :input_schema keys" do
      for tool_def <- CronTools.tool_definitions() do
        assert Map.has_key?(tool_def, :name)
        assert Map.has_key?(tool_def, :description)
        assert Map.has_key?(tool_def, :input_schema)
      end
    end

    test "tool names are cron_schedule, cron_delete, cron_list" do
      names = CronTools.tool_definitions() |> Enum.map(& &1.name)
      assert "cron_schedule" in names
      assert "cron_delete" in names
      assert "cron_list" in names
    end
  end
end
