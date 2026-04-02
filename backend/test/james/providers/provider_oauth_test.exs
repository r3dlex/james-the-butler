defmodule James.Providers.ProviderOAuthTest do
  @moduledoc """
  Unit tests for the ProviderOAuth GenServer.

  The server is started in `setup_all` under its proper module-name so the
  client API functions (`start_flow/2`, `handle_callback/2`, `get_status/1`)
  can find it. Tests are NOT async because they share the named ETS table.
  """

  use ExUnit.Case, async: false

  alias James.Providers.ProviderOAuth

  setup_all do
    # Start the server if not already running (the test env supervisor does not)
    case GenServer.whereis(ProviderOAuth) do
      nil -> start_supervised!(ProviderOAuth)
      _pid -> :already_running
    end

    :ok
  end

  describe "start_flow/2" do
    test "returns error for unsupported provider type" do
      assert {:error, msg} = ProviderOAuth.start_flow("unknown_provider", "user-1")
      assert msg =~ "Unsupported OAuth provider"
    end

    test "returns error when client_id env var is not set for openai_codex" do
      System.delete_env("OPENAI_CODEX_CLIENT_ID")

      assert {:error, msg} = ProviderOAuth.start_flow("openai_codex", "user-1")
      assert msg =~ "OPENAI_CODEX_CLIENT_ID"
    end

    test "returns auth_url and state_key when OPENAI_CLIENT_ID is set" do
      System.put_env("OPENAI_CLIENT_ID", "test-client-id")
      on_exit(fn -> System.delete_env("OPENAI_CLIENT_ID") end)

      assert {:ok, %{auth_url: auth_url, state_key: state_key}} =
               ProviderOAuth.start_flow("openai", "user-2")

      assert String.starts_with?(auth_url, "https://auth.openai.com/authorize")
      assert auth_url =~ "client_id=test-client-id"
      assert auth_url =~ "code_challenge_method=S256"
      assert auth_url =~ "response_type=code"
      assert is_binary(state_key)
      assert byte_size(state_key) > 0
    end

    test "each call generates a unique state key" do
      System.put_env("OPENAI_CLIENT_ID", "test-client-id")
      on_exit(fn -> System.delete_env("OPENAI_CLIENT_ID") end)

      {:ok, %{state_key: key1}} = ProviderOAuth.start_flow("openai", "user-2")
      {:ok, %{state_key: key2}} = ProviderOAuth.start_flow("openai", "user-2")

      refute key1 == key2
    end
  end

  describe "get_status/1" do
    test "returns :not_found for an unknown state key" do
      assert {:error, :not_found} = ProviderOAuth.get_status("totally-unknown-key")
    end

    test "returns :pending immediately after start_flow succeeds" do
      System.put_env("OPENAI_CLIENT_ID", "test-client-id")
      on_exit(fn -> System.delete_env("OPENAI_CLIENT_ID") end)

      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow("openai", "user-3")

      assert {:ok, :pending} = ProviderOAuth.get_status(state_key)
    end
  end

  describe "handle_callback/2" do
    test "returns :state_not_found for an unknown state key" do
      assert {:error, :state_not_found} =
               ProviderOAuth.handle_callback("some-auth-code", "nonexistent-state")
    end

    test "returns :state_expired when entry is past TTL" do
      System.put_env("OPENAI_CLIENT_ID", "test-client-id")
      on_exit(fn -> System.delete_env("OPENAI_CLIENT_ID") end)

      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow("openai", "user-4")

      # Manually expire the entry by overwriting expires_at in ETS
      [{^state_key, entry}] = :ets.lookup(:provider_oauth_states, state_key)
      expired_entry = Map.put(entry, :expires_at, System.system_time(:second) - 1)
      :ets.insert(:provider_oauth_states, {state_key, expired_entry})

      assert {:error, :state_expired} =
               ProviderOAuth.handle_callback("some-auth-code", state_key)
    end
  end
end
