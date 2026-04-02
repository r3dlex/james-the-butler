defmodule James.Planner.MetaPlannerProviderTest do
  @moduledoc """
  TDD tests for MetaPlanner resolving LLM provider from user's DB config.

  These verify that MetaPlanner's decompose_message uses the user's DB-configured
  provider (including api_key) rather than hardcoding LLMProvider.configured().
  """
  use James.DataCase

  alias James.{Accounts, Hosts, ProviderSettings, Sessions, Tasks}
  alias James.OpenClaw.Orchestrator
  alias James.OpenClaw.Supervisor, as: AgentSupervisor
  alias James.Planner.MetaPlanner
  alias James.Test.MockLLMProvider

  defp create_user_with_provider(api_key \\ "planner-db-key") do
    {:ok, user} =
      Accounts.create_user(%{email: "mp_provider_#{System.unique_integer()}@example.com"})

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

  defp create_session(user, attrs \\ %{}) do
    {:ok, host} =
      Hosts.create_host(%{
        name: "mp-provider-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9500"
      })

    {:ok, session} =
      Sessions.create_session(
        Map.merge(%{user_id: user.id, host_id: host.id, name: "MP Provider Test"}, attrs)
      )

    session
  end

  setup do
    if is_nil(Process.whereis(AgentSupervisor)) do
      {:ok, _} = AgentSupervisor.start_link([])
    end

    if is_nil(Process.whereis(Orchestrator)) do
      {:ok, _} = Orchestrator.start_link([])
    end

    if is_nil(Process.whereis(MetaPlanner)) do
      {:ok, _} = MetaPlanner.start_link([])
    end

    MockLLMProvider.flush()
    :ok
  end

  describe "MetaPlanner provider resolution from DB" do
    test "MetaPlanner passes api_key from user DB config to send_message during decomposition" do
      user = create_user_with_provider("planner-secret-key")
      session = create_session(user, %{agent_type: "chat"})

      json_response =
        Jason.encode!([
          %{
            description: "Answer user question",
            risk_level: "read_only",
            agent_type: "chat",
            parallel: false
          }
        ])

      MockLLMProvider.push_response({:ok, %{content: json_response, usage: %{}}})

      MetaPlanner.process_message(session.id, "hello from minimax user")
      Process.sleep(200)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert tasks != []

      # The first send_message call (decomposition) should have received the api_key
      all_opts = MockLLMProvider.all_call_opts()
      # At minimum the decomposition call
      assert all_opts != []
      decompose_opts = hd(all_opts)
      assert Keyword.get(decompose_opts, :api_key) == "planner-secret-key"
    end

    test "MetaPlanner without DB config falls back and still decomposes correctly" do
      {:ok, user} =
        Accounts.create_user(%{email: "mp_noconfig_#{System.unique_integer()}@example.com"})

      session = create_session(user, %{agent_type: "chat"})

      # No mock response queued → MockLLMProvider returns default "Mock response"
      # which is not valid JSON → falls back to single task
      MetaPlanner.process_message(session.id, "hello")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert tasks != []
      assert hd(tasks).description == "Generate response"

      # No api_key should be in opts when no DB config exists
      all_opts = MockLLMProvider.all_call_opts()
      assert all_opts != []
      decompose_opts = hd(all_opts)
      assert Keyword.get(decompose_opts, :api_key) == nil
    end
  end
end
