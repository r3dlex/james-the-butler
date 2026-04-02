defmodule James.Agents.ChatAgentProviderTest do
  @moduledoc """
  TDD tests for ChatAgent resolving provider credentials from user's DB config.

  These tests verify that when a user has an LLM provider config in the DB,
  ChatAgent picks up the api_key from that config and passes it as an opt
  to the provider's stream_message call — rather than relying on a hardcoded
  environment variable.
  """
  use James.DataCase

  alias James.{Accounts, Hosts, ProviderSettings, Sessions, Tasks}
  alias James.Agents.ChatAgent
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp create_user_with_provider_config(api_key \\ "test-db-api-key") do
    {:ok, user} =
      Accounts.create_user(%{email: "ca_provider_#{System.unique_integer()}@example.com"})

    {:ok, _config} =
      ProviderSettings.create_provider_config(%{
        user_id: user.id,
        provider_type: "minimax",
        display_name: "MiniMax",
        api_key: api_key,
        status: "connected"
      })

    user
  end

  defp setup_session_for_user(user) do
    {:ok, host} =
      Hosts.create_host(%{
        name: "ca-provider-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Provider Test Session",
        agent_type: "chat"
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "Hello!"})

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "test task",
        risk_level: "read_only"
      })

    %{session: session, task: task, host: host}
  end

  describe "ChatAgent provider resolution from DB" do
    test "when user has a provider config in DB, ChatAgent passes api_key from DB to stream_message" do
      user = create_user_with_provider_config("super-secret-db-key")
      %{session: session, task: task} = setup_session_for_user(user)

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Response from DB-configured provider",
           usage: %{input_tokens: 5, output_tokens: 10},
           stop_reason: "end_turn"
         }}
      )

      # Pass explicit MockLLMProvider so we can intercept calls in tests,
      # but the api_key from DB config should still be injected as an opt.
      {:ok, pid} =
        ChatAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          provider: MockLLMProvider
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      # Verify that the api_key from the DB config was passed to stream_message
      call_opts = MockLLMProvider.last_call_opts()
      assert call_opts != nil
      assert Keyword.get(call_opts, :api_key) == "super-secret-db-key"
    end

    test "when user has no provider config in DB, ChatAgent falls back without api_key opt" do
      {:ok, user} =
        Accounts.create_user(%{email: "no_config_#{System.unique_integer()}@example.com"})

      %{session: session, task: task} = setup_session_for_user(user)

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Fallback response",
           usage: %{input_tokens: 5, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      # No explicit :provider — falls through to LLMProvider.configured() (MockLLMProvider in test)
      {:ok, pid} = ChatAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      # No api_key from DB — opts should not have :api_key (or it should be nil)
      call_opts = MockLLMProvider.last_call_opts()
      assert Keyword.get(call_opts, :api_key) == nil
    end

    test "format_llm_error for any _API_KEY not configured error returns Settings message" do
      user = create_user_with_provider_config("some-key")
      %{session: session, task: task} = setup_session_for_user(user)

      # Simulate a generic "not configured" error (not just Anthropic-specific)
      MockLLMProvider.push_response({:error, "MINIMAX_API_KEY not configured"})

      {:ok, pid} =
        ChatAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          provider: MockLLMProvider
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      messages = Sessions.list_messages(session.id)
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))
      content = hd(assistant_msgs).content
      # Should produce a helpful Settings/Models message for any _API_KEY error
      assert String.contains?(content, "Settings") and String.contains?(content, "Models")
    end
  end
end
