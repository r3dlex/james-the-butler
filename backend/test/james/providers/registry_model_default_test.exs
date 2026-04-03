defmodule James.Providers.RegistryModelDefaultTest do
  @moduledoc """
  Tests that resolve_from_user_config/1 returns a default model based on the
  user's first provider config type when no explicit ModelDefault exists.
  """

  use James.DataCase

  alias James.{Accounts, Hosts}
  alias James.Providers.Registry
  alias James.ProviderSettings

  defp unique_email, do: "regmdft_#{System.unique_integer([:positive])}@example.com"

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: unique_email()})
    user
  end

  defp create_host do
    {:ok, host} = Hosts.create_host(%{name: "regmdft-host-#{System.unique_integer([:positive])}"})
    host
  end

  defp create_provider_config(user_id, provider_type) do
    attrs =
      case provider_type do
        type when type in ~w(ollama lm_studio openai_compatible) ->
          %{
            user_id: user_id,
            provider_type: type,
            display_name: "Test #{type}",
            base_url: "http://localhost:11434",
            auth_method: "none"
          }

        _ ->
          %{
            user_id: user_id,
            provider_type: provider_type,
            display_name: "Test #{provider_type}",
            api_key: "sk-test-key",
            auth_method: "api_key"
          }
      end

    {:ok, config} = ProviderSettings.create_provider_config(attrs)
    config
  end

  defp create_session(user, host, attrs \\ %{}) do
    base = %{
      user_id: user.id,
      host_id: host.id,
      name: "Test Session",
      agent_type: "chat"
    }

    {:ok, session} = James.Sessions.create_session(Map.merge(base, attrs))
    session
  end

  describe "resolve_from_user_config — default model by provider type" do
    test "returns model 'MiniMax-M2.7' when user has minimax provider config and no ModelDefault" do
      user = create_user()
      host = create_host()
      _config = create_provider_config(user.id, "minimax")
      session = create_session(user, host)

      {_mod, model, _opts} = Registry.resolve_provider(session)
      assert model == "MiniMax-M2.7"
    end

    test "returns model 'claude-sonnet-4-20250514' when user has anthropic provider config and no ModelDefault" do
      user = create_user()
      host = create_host()
      _config = create_provider_config(user.id, "anthropic")
      session = create_session(user, host)

      {_mod, model, _opts} = Registry.resolve_provider(session)
      assert model == "claude-sonnet-4-20250514"
    end

    test "returns model 'gpt-4o' when user has openai provider config and no ModelDefault" do
      user = create_user()
      host = create_host()
      _config = create_provider_config(user.id, "openai")
      session = create_session(user, host)

      {_mod, model, _opts} = Registry.resolve_provider(session)
      assert model == "gpt-4o"
    end

    test "returns model 'gemini-2.0-flash' when user has gemini provider config and no ModelDefault" do
      user = create_user()
      host = create_host()
      _config = create_provider_config(user.id, "gemini")
      session = create_session(user, host)

      {_mod, model, _opts} = Registry.resolve_provider(session)
      assert model == "gemini-2.0-flash"
    end

    test "explicit ModelDefault model_name takes precedence over type default" do
      user = create_user()
      host = create_host()
      config = create_provider_config(user.id, "minimax")

      {:ok, _} =
        ProviderSettings.set_default_model(%{
          user_id: user.id,
          host_id: host.id,
          agent_type: "chat",
          provider_config_id: config.id,
          model_name: "MiniMax-M2.5-highspeed"
        })

      session = create_session(user, host)

      {_mod, model, _opts} = Registry.resolve_provider(session)
      assert model == "MiniMax-M2.5-highspeed"
    end

    test "api_key is still injected as opt when returning default model" do
      user = create_user()
      host = create_host()
      _config = create_provider_config(user.id, "minimax")
      session = create_session(user, host)

      {_mod, _model, opts} = Registry.resolve_provider(session)
      assert Keyword.get(opts, :api_key) == "sk-test-key"
    end
  end
end
