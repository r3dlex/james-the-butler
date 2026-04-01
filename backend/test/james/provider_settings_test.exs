defmodule James.ProviderSettingsTest do
  use James.DataCase

  alias James.Accounts
  alias James.Providers.ProviderConfig
  alias James.ProviderSettings
  alias James.Repo

  defp create_user(email \\ "ps_test@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp anthropic_attrs(user_id) do
    %{
      user_id: user_id,
      provider_type: "anthropic",
      display_name: "My Anthropic",
      api_key: "sk-ant-test-key",
      auth_method: "api_key"
    }
  end

  describe "create_provider_config/1" do
    test "stores config and API key is encrypted in DB" do
      user = create_user()
      assert {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      # The plain api_key should not be a field on the schema
      # The raw DB record should have binary encrypted data
      raw = Repo.get!(ProviderConfig, config.id)
      assert is_binary(raw.api_key_encrypted)
      assert is_binary(raw.api_key_iv)
      # The encrypted value should not equal the plaintext
      refute raw.api_key_encrypted == "sk-ant-test-key"
    end

    test "stores config with status defaulting to untested" do
      user = create_user("default_status@example.com")
      {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))
      assert config.status == "untested"
    end

    test "stores ollama config without api key" do
      user = create_user("ollama_create@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "ollama",
        display_name: "Local Ollama",
        base_url: "http://localhost:11434",
        auth_method: "none"
      }

      assert {:ok, config} = ProviderSettings.create_provider_config(attrs)
      assert config.provider_type == "ollama"
      assert is_nil(config.api_key_encrypted)
    end
  end

  describe "get_provider_config!/1" do
    test "returns config with decrypted key available via virtual field" do
      user = create_user("get_config@example.com")
      {:ok, created} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      fetched = ProviderSettings.get_provider_config!(created.id)
      assert fetched.id == created.id
      assert fetched.decrypted_api_key == "sk-ant-test-key"
    end

    test "raises when config does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        ProviderSettings.get_provider_config!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_provider_configs/1" do
    test "returns all configs for a user" do
      user = create_user("list_configs@example.com")

      {:ok, _c1} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      {:ok, _c2} =
        ProviderSettings.create_provider_config(%{
          user_id: user.id,
          provider_type: "openai",
          display_name: "My OpenAI",
          api_key: "sk-openai-key",
          auth_method: "api_key"
        })

      configs = ProviderSettings.list_provider_configs(user)
      assert length(configs) == 2
    end

    test "returns empty list when user has no configs" do
      user = create_user("empty_configs@example.com")
      assert ProviderSettings.list_provider_configs(user) == []
    end
  end

  describe "update_provider_config/2" do
    test "re-encrypts on api key change" do
      user = create_user("update_key@example.com")
      {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      old_raw = Repo.get!(ProviderConfig, config.id)
      old_encrypted = old_raw.api_key_encrypted

      {:ok, _updated} =
        ProviderSettings.update_provider_config(config, %{api_key: "sk-ant-new-key"})

      new_raw = Repo.get!(ProviderConfig, config.id)
      # New encrypted value should differ from old
      refute new_raw.api_key_encrypted == old_encrypted

      # Fetching should return the new decrypted key
      fetched = ProviderSettings.get_provider_config!(config.id)
      assert fetched.decrypted_api_key == "sk-ant-new-key"
    end

    test "updates display_name without affecting encrypted key" do
      user = create_user("update_name@example.com")
      {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      {:ok, updated} =
        ProviderSettings.update_provider_config(config, %{display_name: "Renamed Anthropic"})

      assert updated.display_name == "Renamed Anthropic"

      fetched = ProviderSettings.get_provider_config!(config.id)
      assert fetched.decrypted_api_key == "sk-ant-test-key"
    end
  end

  describe "delete_provider_config/1" do
    test "removes config from the database" do
      user = create_user("delete_config@example.com")
      {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      assert {:ok, _deleted} = ProviderSettings.delete_provider_config(config)
      assert is_nil(Repo.get(ProviderConfig, config.id))
    end
  end

  describe "update_status/2" do
    test "updates status and sets last_tested_at" do
      user = create_user("update_status@example.com")
      {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      assert is_nil(config.last_tested_at)

      {:ok, updated} = ProviderSettings.update_status(config, "connected")
      assert updated.status == "connected"
      assert %DateTime{} = updated.last_tested_at
    end

    test "can set status to failed" do
      user = create_user("status_failed@example.com")
      {:ok, config} = ProviderSettings.create_provider_config(anthropic_attrs(user.id))

      {:ok, updated} = ProviderSettings.update_status(config, "failed")
      assert updated.status == "failed"
    end
  end

  describe "user isolation" do
    test "list_provider_configs returns only the requesting user's configs" do
      user1 = create_user("isolation_u1@example.com")
      user2 = create_user("isolation_u2@example.com")

      {:ok, _} = ProviderSettings.create_provider_config(anthropic_attrs(user1.id))

      {:ok, _} =
        ProviderSettings.create_provider_config(%{
          user_id: user2.id,
          provider_type: "openai",
          display_name: "User2 OpenAI",
          api_key: "sk-u2-key",
          auth_method: "api_key"
        })

      user1_configs = ProviderSettings.list_provider_configs(user1)
      assert length(user1_configs) == 1
      assert hd(user1_configs).user_id == user1.id

      user2_configs = ProviderSettings.list_provider_configs(user2)
      assert length(user2_configs) == 1
      assert hd(user2_configs).user_id == user2.id
    end
  end
end
