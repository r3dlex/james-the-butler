defmodule James.Providers.ProviderConfigTest do
  use James.DataCase

  alias James.Accounts
  alias James.Providers.ProviderConfig

  defp create_user(email \\ "pc_test@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  describe "changeset/2" do
    test "valid changeset for anthropic provider with api_key" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        provider_type: "anthropic",
        display_name: "My Anthropic",
        api_key_encrypted: <<1, 2, 3>>,
        api_key_iv: <<4, 5, 6>>,
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset for ollama with base_url and auth_method none" do
      user = create_user("ollama_user@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "ollama",
        display_name: "Local Ollama",
        base_url: "http://localhost:11434",
        auth_method: "none"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
    end

    test "rejects unknown provider_type" do
      user = create_user("unknown_type@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "unknown_provider",
        display_name: "Bad Provider",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      refute changeset.valid?
      assert %{provider_type: [_]} = errors_on(changeset)
    end

    test "validates required fields: user_id, provider_type, display_name" do
      changeset = ProviderConfig.changeset(%ProviderConfig{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :user_id)
      assert Map.has_key?(errors, :provider_type)
      assert Map.has_key?(errors, :display_name)
    end

    test "base_url is required for ollama" do
      user = create_user("ollama_no_url@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "ollama",
        display_name: "Ollama No URL",
        auth_method: "none"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      refute changeset.valid?
      assert %{base_url: [_]} = errors_on(changeset)
    end

    test "base_url is required for lm_studio" do
      user = create_user("lm_studio_user@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "lm_studio",
        display_name: "LM Studio",
        auth_method: "none"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      refute changeset.valid?
      assert %{base_url: [_]} = errors_on(changeset)
    end

    test "base_url is required for openai_compatible" do
      user = create_user("compat_user@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "openai_compatible",
        display_name: "Compatible API",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      refute changeset.valid?
      assert %{base_url: [_]} = errors_on(changeset)
    end

    test "base_url is optional for anthropic" do
      user = create_user("anthropic_no_url@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "anthropic",
        display_name: "Anthropic Default",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
    end

    test "base_url is optional for openai" do
      user = create_user("openai_no_url@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "openai",
        display_name: "OpenAI Default",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
    end

    test "base_url is optional for gemini" do
      user = create_user("gemini_no_url@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "gemini",
        display_name: "Gemini Default",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
    end

    test "minimax is valid without explicit base_url and defaults to MiniMax Anthropic endpoint" do
      user = create_user("minimax_no_url@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "minimax",
        display_name: "MiniMax",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :base_url) == "https://api.minimax.io/anthropic"
    end

    test "minimax accepts an explicit base_url override" do
      user = create_user("minimax_custom_url@example.com")

      attrs = %{
        user_id: user.id,
        provider_type: "minimax",
        display_name: "MiniMax Custom",
        base_url: "https://custom.minimax.example.com",
        auth_method: "api_key"
      }

      changeset = ProviderConfig.changeset(%ProviderConfig{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :base_url) == "https://custom.minimax.example.com"
    end
  end
end
