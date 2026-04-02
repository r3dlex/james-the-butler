defmodule James.Providers.ProviderOAuthTest do
  @moduledoc """
  Tests for the ProviderOAuth GenServer.

  Bypass is used to intercept real HTTP calls to OAuth token endpoints.
  Tests are NOT async because they share the named GenServer / ETS table.
  """

  use James.DataCase, async: false

  alias James.Providers.ProviderOAuth

  @bypass_provider_type "openai"

  setup_all do
    case GenServer.whereis(ProviderOAuth) do
      nil -> start_supervised!(ProviderOAuth)
      _pid -> :already_running
    end

    :ok
  end

  setup do
    bypass = Bypass.open()

    bypass_url = "http://localhost:#{bypass.port}"

    # Override provider defs so exchange_code hits Bypass instead of the real endpoint
    Application.put_env(:james, :oauth_provider_defs_override, %{
      @bypass_provider_type => %{
        auth_url: "#{bypass_url}/authorize",
        token_url: "#{bypass_url}/token",
        scopes: "openid",
        client_id_env: "TEST_OAUTH_CLIENT_ID",
        client_secret_env: "TEST_OAUTH_CLIENT_SECRET"
      }
    })

    System.put_env("TEST_OAUTH_CLIENT_ID", "test-client-id")
    System.put_env("TEST_OAUTH_CLIENT_SECRET", "test-client-secret")

    on_exit(fn ->
      Application.delete_env(:james, :oauth_provider_defs_override)
      System.delete_env("TEST_OAUTH_CLIENT_ID")
      System.delete_env("TEST_OAUTH_CLIENT_SECRET")
      Bypass.down(bypass)
    end)

    {:ok, user} = James.Accounts.create_user(%{email: "oauth_#{System.unique_integer()}@example.com"})

    {:ok, bypass: bypass, bypass_url: bypass_url, user: user}
  end

  # ---------------------------------------------------------------------------
  # start_flow/2
  # ---------------------------------------------------------------------------

  describe "start_flow/2" do
    test "returns error for unsupported provider type" do
      assert {:error, msg} = ProviderOAuth.start_flow("unknown_provider", "user-1")
      assert msg =~ "Unsupported OAuth provider"
    end

    test "returns error when client_id env var is not set", %{user: user} do
      System.delete_env("TEST_OAUTH_CLIENT_ID")

      assert {:error, msg} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)
      assert msg =~ "TEST_OAUTH_CLIENT_ID"
    end

    test "returns auth_url and state_key when client_id is present", %{user: user} do
      {:ok, %{auth_url: auth_url, state_key: state_key}} =
        ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      assert auth_url =~ "test-client-id"
      assert auth_url =~ "code_challenge_method=S256"
      assert auth_url =~ "response_type=code"
      assert is_binary(state_key) and byte_size(state_key) > 0
    end

    test "each call generates a unique state key", %{user: user} do
      {:ok, %{state_key: key1}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)
      {:ok, %{state_key: key2}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)
      refute key1 == key2
    end
  end

  # ---------------------------------------------------------------------------
  # get_status/1
  # ---------------------------------------------------------------------------

  describe "get_status/1" do
    test "returns :not_found for an unknown state key" do
      assert {:error, :not_found} = ProviderOAuth.get_status("totally-unknown-key")
    end

    test "returns :pending immediately after start_flow", %{user: user} do
      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)
      assert {:ok, :pending} = ProviderOAuth.get_status(state_key)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_callback/2
  # ---------------------------------------------------------------------------

  describe "handle_callback/2" do
    test "returns :state_not_found for an unknown state key" do
      assert {:error, :state_not_found} =
               ProviderOAuth.handle_callback("some-auth-code", "nonexistent-state")
    end

    test "returns :state_expired when entry is past TTL", %{user: user} do
      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      [{^state_key, entry}] = :ets.lookup(:provider_oauth_states, state_key)
      :ets.insert(:provider_oauth_states, {state_key, Map.put(entry, :expires_at, 0)})

      assert {:error, :state_expired} =
               ProviderOAuth.handle_callback("some-auth-code", state_key)
    end

    test "exchanges authorization code and persists provider config", %{
      bypass: bypass,
      user: user
    } do
      Bypass.expect_once(bypass, "POST", "/token", fn conn ->
        body =
          Jason.encode!(%{
            access_token: "access-tok-123",
            refresh_token: "refresh-tok-456",
            token_type: "Bearer",
            expires_in: 3600
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, body)
      end)

      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      assert {:ok, provider} = ProviderOAuth.handle_callback("auth-code", state_key)
      assert provider != nil
      assert provider.provider_type == @bypass_provider_type
      assert provider.auth_method == "oauth"

      # State should now be :completed
      assert {:ok, :completed, ^provider} = ProviderOAuth.get_status(state_key)
    end

    test "returns error when token exchange returns non-200", %{bypass: bypass, user: user} do
      Bypass.expect_once(bypass, "POST", "/token", fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "invalid_grant"}))
      end)

      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      assert {:error, reason} = ProviderOAuth.handle_callback("bad-code", state_key)
      assert is_binary(reason)
    end

    test "returns error when token endpoint is unreachable", %{bypass: bypass, user: user} do
      # Take bypass down to simulate unreachable endpoint
      Bypass.down(bypass)

      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      assert {:error, reason} = ProviderOAuth.handle_callback("code", state_key)
      assert is_binary(reason)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info :sweep_expired
  # ---------------------------------------------------------------------------

  describe "sweep_expired timer" do
    test "removes entries with expired TTL from ETS", %{user: user} do
      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      # Manually expire the entry
      [{^state_key, entry}] = :ets.lookup(:provider_oauth_states, state_key)
      :ets.insert(:provider_oauth_states, {state_key, Map.put(entry, :expires_at, 0)})

      # Trigger the sweep directly (bypasses the 60 s timer)
      send(GenServer.whereis(ProviderOAuth), :sweep_expired)
      # Allow the GenServer message to be processed
      :sys.get_state(ProviderOAuth)

      assert :ets.lookup(:provider_oauth_states, state_key) == []
    end

    test "retains entries that have not yet expired", %{user: user} do
      {:ok, %{state_key: state_key}} = ProviderOAuth.start_flow(@bypass_provider_type, user.id)

      send(GenServer.whereis(ProviderOAuth), :sweep_expired)
      :sys.get_state(ProviderOAuth)

      assert [{^state_key, _}] = :ets.lookup(:provider_oauth_states, state_key)
    end
  end
end
