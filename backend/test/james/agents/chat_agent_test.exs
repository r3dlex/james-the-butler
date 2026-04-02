defmodule James.Agents.ChatAgentTest do
  @moduledoc """
  Tests for ChatAgent using the MockLLMProvider injected via config.
  """
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Agents.ChatAgent
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} =
      Accounts.create_user(%{email: "chat_agent_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "chat-agent-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Chat Agent Test",
        agent_type: "chat"
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "Hello!"})

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "chat task",
        risk_level: "read_only"
      })

    %{session: session, task: task, user: user}
  end

  describe "ChatAgent with mock LLM" do
    test "completes successfully and saves assistant message" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Hello! How can I help you today?",
           usage: %{input_tokens: 10, output_tokens: 15},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      assert assistant_msgs != []
      assert hd(assistant_msgs).content =~ "Hello"
    end

    test "marks task as completed on success" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Done!",
           usage: %{input_tokens: 5, output_tokens: 3},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"
    end

    test "marks task as failed on LLM error" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "LLM unavailable"})

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      updated = Tasks.get_task(task.id)
      assert updated.status == "failed"
    end

    test "saves error as assistant message in DB on LLM error" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "LLM unavailable"})

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      assert length(assistant_msgs) == 1
      assert String.contains?(List.first(assistant_msgs).content, "⚠️")
    end

    test "broadcasts assistant_message on LLM error to close streaming" do
      %{session: session, task: task} = setup_session()

      Phoenix.PubSub.subscribe(James.PubSub, "session:#{session.id}")

      MockLLMProvider.push_response({:error, "LLM unavailable"})

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      assert_received {:assistant_message, msg}
      assert msg.role == "assistant"
      assert String.contains?(msg.content, "⚠️")
    end

    test "formats missing API key error with helpful Settings message" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "ANTHROPIC_API_KEY not configured"})

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      content = List.first(assistant_msgs).content
      assert String.contains?(content, "Settings")
      assert String.contains?(content, "Models")
    end

    test "starts without task_id (nil task) without crashing" do
      %{session: session} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "No task",
           usage: %{},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = ChatAgent.start_link(session_id: session.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000
    end

    test "broadcasts chunks to session PubSub topic" do
      %{session: session, task: task} = setup_session()

      Phoenix.PubSub.subscribe(James.PubSub, "session:#{session.id}")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "streamed chunk text",
           usage: %{input_tokens: 5, output_tokens: 10},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      # Should have received at least an assistant_chunk broadcast
      assert_received {:assistant_chunk, _}
    end

    test "uses explicitly provided :provider module instead of configured default" do
      %{session: session, task: task} = setup_session()

      # Push a response for our custom provider
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "From custom provider",
           usage: %{input_tokens: 3, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        ChatAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          provider: James.Test.MockLLMProvider
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      assert assistant_msgs != []
      assert hd(assistant_msgs).content == "From custom provider"
    end

    test "falls back to LLMProvider.configured() when no :provider opt is given" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Fallback response",
           usage: %{input_tokens: 2, output_tokens: 4},
           stop_reason: "end_turn"
         }}
      )

      # No :provider opt — should still use MockLLMProvider because that is what
      # the test config sets as the default (James.Test.MockLLMProvider).
      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      assert assistant_msgs != []
      assert hd(assistant_msgs).content == "Fallback response"
    end

    test "handles session with no user messages (build_memory_context empty)" do
      {:ok, user} =
        Accounts.create_user(%{email: "chat_nomsg_#{System.unique_integer()}@example.com"})

      {:ok, host} =
        Hosts.create_host(%{
          name: "no-msg-host-#{System.unique_integer()}",
          endpoint: "http://localhost:9999"
        })

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "No User Msg Test",
          agent_type: "chat"
        })

      # No user messages created

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Hello.",
           usage: %{input_tokens: 5, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = ChatAgent.start_link(session_id: session.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000
    end
  end
end
