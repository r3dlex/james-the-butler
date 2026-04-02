defmodule James.Integration.ProviderFlowTest do
  @moduledoc """
  E2E integration tests for the provider configuration and resolution flow:
    - Creating provider configs and testing connections
    - Setting model defaults and resolving via provider_for_session/2
    - Fallback behaviour when configs are deleted
    - Provider with "failed" status still resolves (status is informational)
  """

  use James.DataCase

  alias James.{Accounts, Hosts}
  alias James.LLMProvider
  alias James.Providers.{Anthropic, Registry}
  alias James.ProviderSettings

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_email, do: "pf_#{System.unique_integer([:positive])}@example.com"

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: unique_email()})
    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{name: "pf-host-#{System.unique_integer([:positive])}"})

    host
  end

  defp create_anthropic_config(user_id, api_key \\ "sk-ant-test-key") do
    {:ok, config} =
      ProviderSettings.create_provider_config(%{
        user_id: user_id,
        provider_type: "anthropic",
        display_name: "Integration Anthropic",
        api_key: api_key,
        auth_method: "api_key"
      })

    config
  end

  defp create_session(user, host, attrs \\ %{}) do
    base = %{
      user_id: user.id,
      host_id: host.id,
      name: "Integration Session",
      agent_type: "chat"
    }

    {:ok, session} = James.Sessions.create_session(Map.merge(base, attrs))
    session
  end

  # ---------------------------------------------------------------------------
  # 1. Create user → provider config → mock test connection → status "connected"
  # ---------------------------------------------------------------------------

  describe "provider config lifecycle" do
    test "create user → create provider config (Anthropic) → update status to connected" do
      user = create_user()
      config = create_anthropic_config(user.id)

      # Initial status should be "untested"
      assert config.status == "untested"
      assert is_nil(config.last_tested_at)

      # Simulate a successful connection test by calling update_status directly
      # (mirrors what ConnectionTester does after a successful HTTP call)
      assert {:ok, updated} = ProviderSettings.update_status(config, "connected")
      assert updated.status == "connected"
      assert %DateTime{} = updated.last_tested_at

      # Verify we can fetch it back and the status persists
      fetched = ProviderSettings.get_provider_config!(config.id)
      assert fetched.status == "connected"
    end

    test "provider config decrypts the API key on retrieval" do
      user = create_user()
      config = create_anthropic_config(user.id, "sk-ant-secret-123")

      fetched = ProviderSettings.get_provider_config!(config.id)
      assert fetched.decrypted_api_key == "sk-ant-secret-123"
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Set model default for host + agent_type "chat" → default_model_for/3 returns it
  # ---------------------------------------------------------------------------

  describe "model default resolution" do
    test "set model default → default_model_for/3 returns it" do
      user = create_user()
      host = create_host()
      config = create_anthropic_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "claude-sonnet-4-20250514"
        })

      result = ProviderSettings.default_model_for(user.id, host.id, "chat")
      assert result != nil
      assert result.model_name == "claude-sonnet-4-20250514"
      assert result.provider_config_id == config.id
    end

    test "different agent_types get independent model defaults" do
      user = create_user()
      host = create_host()
      config = create_anthropic_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "claude-sonnet-4-20250514"
        })

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "code",
          provider_config_id: config.id,
          model_name: "claude-opus-4-5"
        })

      chat_default = ProviderSettings.default_model_for(user.id, host.id, "chat")
      code_default = ProviderSettings.default_model_for(user.id, host.id, "code")

      assert chat_default.model_name == "claude-sonnet-4-20250514"
      assert code_default.model_name == "claude-opus-4-5"
    end
  end

  # ---------------------------------------------------------------------------
  # 3. provider_for_session/2 resolves the full chain
  # ---------------------------------------------------------------------------

  describe "provider_for_session/2 — full chain resolution" do
    test "session → agent_type → model default → provider config → provider module" do
      user = create_user()
      host = create_host()
      config = create_anthropic_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "claude-sonnet-4-20250514"
        })

      session = create_session(user, host)

      assert {:ok, %{module: mod, model: model}} =
               Registry.provider_for_session(session, "chat")

      assert mod == Anthropic
      assert model == "claude-sonnet-4-20250514"
    end

    test "resolve_provider/1 convenience wrapper returns full triple" do
      user = create_user()
      host = create_host()
      config = create_anthropic_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "claude-sonnet-4-20250514"
        })

      session = create_session(user, host)

      {mod, model, opts} = Registry.resolve_provider(session)
      assert mod == Anthropic
      assert model == "claude-sonnet-4-20250514"
      assert Keyword.get(opts, :api_key) == "sk-ant-test-key"
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Delete provider config → model default cascade-deleted → falls back to global
  # ---------------------------------------------------------------------------

  describe "provider_for_session/2 — fallback after deletion" do
    test "deleting provider config (cascades model default) causes fallback to global" do
      user = create_user()
      host = create_host()
      config = create_anthropic_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "claude-sonnet-4-20250514"
        })

      # Verify it resolves correctly before deletion
      session = create_session(user, host)
      assert {:ok, %{module: Anthropic}} = Registry.provider_for_session(session, "chat")

      # Delete the provider config — cascade also removes the model_default row
      {:ok, _} = ProviderSettings.delete_provider_config(config)

      # Now no model default exists → falls back to global configured provider
      assert {:ok, %{module: global_mod, model: nil}} =
               Registry.provider_for_session(session, "chat")

      assert global_mod == LLMProvider.configured()

      # resolve_provider/1 also returns global fallback
      {mod, _model, _opts} = Registry.resolve_provider(session)
      assert mod == LLMProvider.configured()
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Provider with status "failed" still resolves (status is informational)
  # ---------------------------------------------------------------------------

  describe "provider_for_session/2 — failed status is not blocking" do
    test "provider with status 'failed' still resolves correctly" do
      user = create_user()
      host = create_host()
      config = create_anthropic_config(user.id)

      # Mark connection as failed
      {:ok, failed_config} = ProviderSettings.update_status(config, "failed")
      assert failed_config.status == "failed"

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "claude-sonnet-4-20250514"
        })

      session = create_session(user, host)

      # Despite "failed" status, resolution still succeeds — status is informational
      assert {:ok, %{module: Anthropic, model: "claude-sonnet-4-20250514"}} =
               Registry.provider_for_session(session, "chat")
    end
  end
end
