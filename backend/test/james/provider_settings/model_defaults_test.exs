defmodule James.ProviderSettings.ModelDefaultsTest do
  use James.DataCase

  alias James.Accounts
  alias James.Hosts
  alias James.ProviderSettings

  defp create_user(email \\ "md_test@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_host(name \\ "Test Host") do
    {:ok, host} = Hosts.create_host(%{name: name})
    host
  end

  defp create_provider_config(user_id) do
    {:ok, config} =
      ProviderSettings.create_provider_config(%{
        user_id: user_id,
        provider_type: "anthropic",
        display_name: "Anthropic",
        api_key: "sk-ant-test",
        auth_method: "api_key"
      })

    config
  end

  defp valid_attrs(user_id, host_id, provider_config_id, agent_type \\ "chat") do
    %{
      user_id: user_id,
      host_id: host_id,
      agent_type: agent_type,
      provider_config_id: provider_config_id,
      model_name: "claude-3-5-sonnet-20241022"
    }
  end

  describe "set_default_model/1" do
    test "creates a model default record with valid attrs" do
      user = create_user()
      host = create_host()
      config = create_provider_config(user.id)

      attrs = valid_attrs(user.id, host.id, config.id, "chat")

      assert {:ok, default} = ProviderSettings.set_default_model(attrs)
      assert default.user_id == user.id
      assert default.host_id == host.id
      assert default.agent_type == "chat"
      assert default.provider_config_id == config.id
      assert default.model_name == "claude-3-5-sonnet-20241022"
    end

    test "upserts on duplicate (user_id, host_id, agent_type) — updates model_name" do
      user = create_user("upsert_user@example.com")
      host = create_host("Upsert Host")
      config = create_provider_config(user.id)

      attrs = valid_attrs(user.id, host.id, config.id, "code")
      assert {:ok, _first} = ProviderSettings.set_default_model(attrs)

      updated_attrs = Map.put(attrs, :model_name, "claude-opus-4-5")
      assert {:ok, updated} = ProviderSettings.set_default_model(updated_attrs)
      assert updated.model_name == "claude-opus-4-5"
      assert updated.user_id == user.id
      assert updated.host_id == host.id
      assert updated.agent_type == "code"

      # Only one record should exist for this user/host/agent_type
      defaults = ProviderSettings.list_model_defaults(user)
      assert length(defaults) == 1
    end

    test "validates agent_type in allowed list" do
      user = create_user("valid_type@example.com")
      host = create_host("Valid Type Host")
      config = create_provider_config(user.id)

      for agent_type <- ~w(chat code research security desktop browser) do
        attrs = valid_attrs(user.id, host.id, config.id, agent_type)
        assert {:ok, _default} = ProviderSettings.set_default_model(attrs)
        # Clean up for next iteration (upsert, so it's fine)
      end
    end

    test "rejects invalid agent_type" do
      user = create_user("invalid_type@example.com")
      host = create_host("Invalid Type Host")
      config = create_provider_config(user.id)

      attrs = valid_attrs(user.id, host.id, config.id, "invalid_agent")
      assert {:error, changeset} = ProviderSettings.set_default_model(attrs)
      assert %{agent_type: [_]} = errors_on(changeset)
    end
  end

  describe "default_model_for/3" do
    test "returns %{model_name, provider_config_id} for given user/host/agent_type" do
      user = create_user("lookup_user@example.com")
      host = create_host("Lookup Host")
      config = create_provider_config(user.id)

      attrs = valid_attrs(user.id, host.id, config.id, "research")
      {:ok, _} = ProviderSettings.set_default_model(attrs)

      result = ProviderSettings.default_model_for(user.id, host.id, "research")
      assert result.model_name == "claude-3-5-sonnet-20241022"
      assert result.provider_config_id == config.id
    end

    test "returns nil when not set" do
      user = create_user("no_default@example.com")
      host = create_host("No Default Host")

      result = ProviderSettings.default_model_for(user.id, host.id, "chat")
      assert is_nil(result)
    end
  end

  describe "list_model_defaults/1" do
    test "returns all defaults for a user" do
      user = create_user("list_all@example.com")
      host1 = create_host("Host One")
      host2 = create_host("Host Two")
      config = create_provider_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(valid_attrs(user.id, host1.id, config.id, "chat"))

      {:ok, _} =
        ProviderSettings.set_default_model(valid_attrs(user.id, host2.id, config.id, "code"))

      defaults = ProviderSettings.list_model_defaults(user)
      assert length(defaults) == 2
      assert Enum.all?(defaults, &(&1.user_id == user.id))
    end

    test "returns empty list when user has no defaults" do
      user = create_user("empty_defaults@example.com")
      assert ProviderSettings.list_model_defaults(user) == []
    end
  end

  describe "list_model_defaults_for_host/2" do
    test "filters by user and host" do
      user = create_user("host_filter@example.com")
      host1 = create_host("Filter Host One")
      host2 = create_host("Filter Host Two")
      config = create_provider_config(user.id)

      {:ok, _} =
        ProviderSettings.set_default_model(valid_attrs(user.id, host1.id, config.id, "chat"))

      {:ok, _} =
        ProviderSettings.set_default_model(valid_attrs(user.id, host1.id, config.id, "code"))

      {:ok, _} =
        ProviderSettings.set_default_model(valid_attrs(user.id, host2.id, config.id, "research"))

      host1_defaults = ProviderSettings.list_model_defaults_for_host(user.id, host1.id)
      assert length(host1_defaults) == 2
      assert Enum.all?(host1_defaults, &(&1.host_id == host1.id))

      host2_defaults = ProviderSettings.list_model_defaults_for_host(user.id, host2.id)
      assert length(host2_defaults) == 1
      assert hd(host2_defaults).agent_type == "research"
    end

    test "returns empty list when no defaults for user/host combination" do
      user = create_user("empty_host@example.com")
      host = create_host("Empty Filter Host")

      assert ProviderSettings.list_model_defaults_for_host(user.id, host.id) == []
    end
  end
end
