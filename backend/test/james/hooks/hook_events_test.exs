defmodule James.Hooks.HookEventsTest do
  use James.DataCase

  alias James.Hooks.{Dispatcher, Hook}

  @new_events ~w[
    session_setup
    user_prompt_submit
    subagent_start
    subagent_stop
    teammate_idle
    permission_denied
    post_tool_use_failure
  ]

  # ---------------------------------------------------------------------------
  # 1. All 7 new events are present in Hook.valid_events/0
  # ---------------------------------------------------------------------------

  describe "Hook.valid_events/0" do
    test "contains all 7 new hook events" do
      valid = Hook.valid_events()

      for event <- @new_events do
        assert event in valid,
               "Expected #{inspect(event)} to be in valid_events, got: #{inspect(valid)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Hook changeset accepts each new event string
  # ---------------------------------------------------------------------------

  describe "Hook.changeset/2 accepts new events" do
    setup do
      {:ok, user} = James.Accounts.create_user(%{email: "hook_events_user@example.com"})
      %{user: user}
    end

    for event <- ~w[
          session_setup
          user_prompt_submit
          subagent_start
          subagent_stop
          teammate_idle
          permission_denied
          post_tool_use_failure
        ] do
      @event event
      test "accepts event #{event}", %{user: user} do
        cs =
          Hook.changeset(%Hook{}, %{
            user_id: user.id,
            event: @event,
            type: "command",
            config: %{"command" => "echo ok"}
          })

        assert cs.valid?, "Changeset should be valid for event=#{@event}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Hook changeset rejects unknown events
  # ---------------------------------------------------------------------------

  describe "Hook.changeset/2 rejects invalid events" do
    setup do
      {:ok, user} = James.Accounts.create_user(%{email: "hook_events_invalid@example.com"})
      %{user: user}
    end

    test "rejects an event string not in the list", %{user: user} do
      cs =
        Hook.changeset(%Hook{}, %{
          user_id: user.id,
          event: "invalid_event",
          type: "command",
          config: %{"command" => "echo ok"}
        })

      refute cs.valid?
      assert {:event, _} = List.keyfind(cs.errors, :event, 0)
    end
  end

  # ---------------------------------------------------------------------------
  # 4–10. Dispatcher.fire/2 (atom, payload) returns :ok for each new event
  # ---------------------------------------------------------------------------

  describe "Dispatcher.fire/2 with system-level atom events" do
    test "session_setup fires without crash" do
      assert :ok == Dispatcher.fire(:session_setup, %{session_id: "123"})
    end

    test "user_prompt_submit fires without crash" do
      assert :ok == Dispatcher.fire(:user_prompt_submit, %{session_id: "123", message: "hi"})
    end

    test "subagent_start fires without crash" do
      assert :ok ==
               Dispatcher.fire(:subagent_start, %{
                 parent_session_id: "1",
                 sub_session_id: "2"
               })
    end

    test "subagent_stop fires without crash" do
      assert :ok ==
               Dispatcher.fire(:subagent_stop, %{
                 parent_session_id: "1",
                 sub_session_id: "2",
                 status: :done
               })
    end

    test "teammate_idle fires without crash" do
      assert :ok ==
               Dispatcher.fire(:teammate_idle, %{session_id: "1", idle_minutes: 15})
    end

    test "permission_denied fires without crash" do
      assert :ok ==
               Dispatcher.fire(:permission_denied, %{
                 session_id: "1",
                 task_id: "2",
                 risk_level: :destructive
               })
    end

    test "post_tool_use_failure fires without crash" do
      assert :ok ==
               Dispatcher.fire(:post_tool_use_failure, %{
                 session_id: "1",
                 tool_name: "bash",
                 error_message: "timeout"
               })
    end
  end
end
