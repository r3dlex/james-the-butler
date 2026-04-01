defmodule James.Integration.ChatFlowTest do
  @moduledoc """
  Integration tests for the full chat flow:
  MetaPlanner → Orchestrator → ChatAgent → Sessions/PubSub.
  """

  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.OpenClaw.Orchestrator
  alias James.OpenClaw.Supervisor, as: AgentSupervisor
  alias James.Planner.MetaPlanner
  alias James.Test.MockLLMProvider

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_email, do: "integration_#{System.unique_integer([:positive])}@example.com"

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: unique_email()})
    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "integration-host-#{System.unique_integer([:positive])}",
        endpoint: "http://localhost:9900"
      })

    host
  end

  defp create_session(user, host, attrs) do
    {:ok, session} =
      Sessions.create_session(
        Map.merge(
          %{user_id: user.id, host_id: host.id, name: "Integration Session", agent_type: "chat"},
          attrs
        )
      )

    session
  end

  # Drain the process mailbox and return all collected messages (within timeout).
  defp receive_all(acc \\ []) do
    receive do
      msg -> receive_all([msg | acc])
    after
      200 -> Enum.reverse(acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Setup — start the full OpenClaw + MetaPlanner stack
  # ---------------------------------------------------------------------------

  setup do
    MockLLMProvider.flush()

    if is_nil(Process.whereis(AgentSupervisor)) do
      {:ok, _} = AgentSupervisor.start_link([])
    end

    # Fresh orchestrator per test
    if pid = Process.whereis(Orchestrator) do
      GenServer.stop(pid, :normal)
      Process.sleep(20)
    end

    {:ok, orchestrator} = Orchestrator.start_link([])

    if is_nil(Process.whereis(MetaPlanner)) do
      {:ok, _} = MetaPlanner.start_link([])
    end

    on_exit(fn ->
      MockLLMProvider.flush()

      if Process.alive?(orchestrator) do
        GenServer.stop(orchestrator, :normal)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Test 1 — Full chat flow
  # ---------------------------------------------------------------------------

  describe "full chat flow" do
    test "message saved, planner decomposes, agent responds, response saved, PubSub broadcast received" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      # Subscribe to the session PubSub topic before doing anything
      Phoenix.PubSub.subscribe(James.PubSub, "session:#{session.id}")
      Phoenix.PubSub.subscribe(James.PubSub, "planner:#{session.id}")

      # 1. Push mock responses:
      #    - First pop  → planner's LLM decomposition call
      #    - Second pop → chat agent's stream_message call
      decomposition_json =
        Jason.encode!([
          %{
            description: "Answer user greeting",
            risk_level: "read_only",
            agent_type: "chat",
            parallel: false
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: decomposition_json, usage: %{}}})

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Hello! How can I help you today?",
           usage: %{input_tokens: 10, output_tokens: 15},
           stop_reason: "end_turn"
         }}
      )

      # 2. Save user message and dispatch to planner
      {:ok, user_msg} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "user",
          content: "Hello!"
        })

      assert user_msg.role == "user"

      MetaPlanner.process_message(session.id, "Hello!")

      # 3. Allow async processing to complete
      Process.sleep(500)

      # 4. Verify task was created by the planner
      tasks = Tasks.list_tasks(session_id: session.id)
      assert tasks != [], "Expected at least one task to be created"

      task = hd(tasks)
      assert task.description == "Answer user greeting"
      assert task.risk_level == "read_only"

      # 5. Verify assistant message was saved by the agent
      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      assert assistant_msgs != [], "Expected assistant message to be saved"
      assert hd(assistant_msgs).content =~ "Hello"

      # 6. Verify PubSub broadcasts were received
      all_msgs = receive_all()

      planner_steps = Enum.filter(all_msgs, &match?({:planner_step, _}, &1))
      assert planner_steps != [], "Expected planner step broadcasts"

      assistant_chunk_or_msg =
        Enum.any?(all_msgs, fn
          {:assistant_chunk, _} -> true
          {:assistant_message, _} -> true
          _ -> false
        end)

      assert assistant_chunk_or_msg, "Expected assistant_chunk or assistant_message broadcast"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2 — Confirmed mode with destructive task
  # ---------------------------------------------------------------------------

  describe "confirmed mode with destructive task" do
    test "destructive task in confirmed session stays pending and broadcasts awaiting_approval" do
      user = create_user()
      host = create_host()

      session =
        create_session(user, host, %{
          agent_type: "desktop",
          execution_mode: "confirmed"
        })

      Phoenix.PubSub.subscribe(James.PubSub, "planner:#{session.id}")

      # Return a destructive task from the LLM
      decomposition_json =
        Jason.encode!([
          %{
            description: "Delete all temp files",
            risk_level: "destructive",
            agent_type: "desktop",
            parallel: false
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: decomposition_json, usage: %{}}})

      MetaPlanner.process_message(session.id, "clean up temp files")
      Process.sleep(300)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert tasks != [], "Expected at least one task"

      destructive_task = Enum.find(tasks, fn t -> t.risk_level == "destructive" end)
      assert destructive_task != nil, "Expected a destructive task to be created"

      # In confirmed mode, destructive tasks should not proceed to running
      assert destructive_task.status in ["pending", "pending_approval"],
             "Expected destructive task to be held, got: #{destructive_task.status}"

      # Verify awaiting_approval planner step broadcast
      all_msgs = receive_all()

      awaiting =
        Enum.any?(all_msgs, fn
          {:planner_step, %{type: "awaiting_approval"}} -> true
          _ -> false
        end)

      assert awaiting,
             "Expected awaiting_approval planner step broadcast for destructive task in confirmed mode"
    end

    test "non-destructive task in confirmed session proceeds normally" do
      user = create_user()
      host = create_host()

      session =
        create_session(user, host, %{
          agent_type: "chat",
          execution_mode: "confirmed"
        })

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Here is some information.",
           usage: %{input_tokens: 5, output_tokens: 8},
           stop_reason: "end_turn"
         }}
      )

      # Let the planner use the fallback (non-JSON → single read_only task)
      MetaPlanner.process_message(session.id, "what is the weather?")
      Process.sleep(400)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert tasks != []

      read_only_task = Enum.find(tasks, fn t -> t.risk_level == "read_only" end)

      if read_only_task do
        # A read_only task in confirmed mode should still be dispatched (not gated)
        assert read_only_task.status in ["running", "completed", "failed"],
               "Expected read_only task to be dispatched in confirmed mode, got: #{read_only_task.status}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3 — Session lifecycle integration
  # ---------------------------------------------------------------------------

  describe "session lifecycle integration" do
    test "messages are preserved across suspend and resume" do
      user = create_user()
      host = create_host()

      # Use Orchestrator.start_session to get an active session with an agent PID
      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Lifecycle Integration",
          agent_type: "chat"
        })

      # Create a user message before suspension
      {:ok, msg_before} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "user",
          content: "Message before suspend"
        })

      assert msg_before.content == "Message before suspend"

      # Suspend the session — this also creates an implicit checkpoint
      assert :ok = Orchestrator.suspend_session(session.id)
      Process.sleep(50)

      refreshed = Sessions.get_session(session.id)
      assert refreshed.status == "suspended"

      # Verify checkpoint was created on suspend
      checkpoints = Sessions.list_checkpoints(session.id)
      assert checkpoints != [], "Expected checkpoint to be created on suspend"
      assert hd(checkpoints).type == "implicit"

      # Verify messages are still present after suspension
      messages_after_suspend = Sessions.list_messages(session.id)
      assert Enum.any?(messages_after_suspend, fn m -> m.content == "Message before suspend" end)

      # Resume the session
      assert {:ok, new_pid} = Orchestrator.resume_session(session.id)
      assert is_pid(new_pid)
      Process.sleep(100)

      resumed = Sessions.get_session(session.id)
      assert resumed.status == "active"

      # Push a mock LLM response for the chat agent that runs on resume
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Back online!",
           usage: %{input_tokens: 5, output_tokens: 3},
           stop_reason: "end_turn"
         }}
      )

      # Send a second message after resume
      {:ok, msg_after} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "user",
          content: "Message after resume"
        })

      assert msg_after.content == "Message after resume"

      # Both messages must be present
      all_messages = Sessions.list_messages(session.id)
      contents = Enum.map(all_messages, & &1.content)
      assert "Message before suspend" in contents
      assert "Message after resume" in contents
    end

    test "checkpoint snapshot contains conversation at time of suspension" do
      user = create_user()
      host = create_host()

      {:ok, session, _pid} =
        Orchestrator.start_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Checkpoint Snapshot Test",
          agent_type: "chat"
        })

      {:ok, _} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "user",
          content: "First message"
        })

      {:ok, _} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "assistant",
          content: "First reply"
        })

      :ok = Orchestrator.suspend_session(session.id)
      Process.sleep(50)

      checkpoints = Sessions.list_checkpoints(session.id)
      assert length(checkpoints) == 1

      checkpoint = hd(checkpoints)
      snapshot_messages = get_in(checkpoint.conversation_snapshot, ["messages"]) || []
      assert snapshot_messages != [], "Expected at least one message in checkpoint snapshot"

      roles = Enum.map(snapshot_messages, fn m -> m["role"] end)
      # The snapshot must include the user message we explicitly created
      assert "user" in roles
    end
  end
end
