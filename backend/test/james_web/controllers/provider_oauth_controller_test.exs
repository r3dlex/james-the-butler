defmodule JamesWeb.ProviderOAuthControllerTest do
  @moduledoc """
  Integration tests for the provider OAuth endpoints.
  Bypass is used to intercept token endpoint HTTP calls.
  Tests are NOT async because they share the named GenServer / ETS table.
  """

  use JamesWeb.ConnCase, async: false

  alias James.{Accounts, Auth}
  alias James.Providers.ProviderOAuth

  @bypass_provider "openai"

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

    Application.put_env(:james, :oauth_provider_defs_override, %{
      @bypass_provider => %{
        auth_url: "#{bypass_url}/authorize",
        token_url: "#{bypass_url}/token",
        scopes: "openid",
        client_id_env: "CTRL_TEST_CLIENT_ID",
        client_secret_env: "CTRL_TEST_CLIENT_SECRET"
      }
    })

    System.put_env("CTRL_TEST_CLIENT_ID", "ctrl-client-id")
    System.put_env("CTRL_TEST_CLIENT_SECRET", "ctrl-client-secret")

    on_exit(fn ->
      Application.delete_env(:james, :oauth_provider_defs_override)
      System.delete_env("CTRL_TEST_CLIENT_ID")
      System.delete_env("CTRL_TEST_CLIENT_SECRET")
      Bypass.down(bypass)
    end)

    {:ok, user} =
      Accounts.create_user(%{email: "oauth_ctrl_#{System.unique_integer()}@example.com"})

    {:ok, token} = Auth.generate_token(user)

    authed = fn conn ->
      put_req_header(conn, "authorization", "Bearer #{token}")
    end

    {:ok, user: user, authed: authed, bypass: bypass, bypass_url: bypass_url}
  end

  # ---------------------------------------------------------------------------
  # POST /api/providers/oauth/start
  # ---------------------------------------------------------------------------

  describe "POST /api/providers/oauth/start" do
    test "returns 422 for unsupported provider", %{conn: conn, authed: authed} do
      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: "unknown"})

      assert json_response(conn, 422)["error"] =~ "Unsupported"
    end

    test "returns 422 when env var is not set", %{conn: conn, authed: authed} do
      System.delete_env("CTRL_TEST_CLIENT_ID")

      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: @bypass_provider})

      assert json_response(conn, 422)["error"] =~ "CTRL_TEST_CLIENT_ID"
    end

    test "returns 400 when provider_type is missing", %{conn: conn, authed: authed} do
      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{})

      assert json_response(conn, 400)["error"] =~ "provider_type"
    end

    test "returns auth_url and state_key when client_id is present", %{
      conn: conn,
      authed: authed
    } do
      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: @bypass_provider})

      body = json_response(conn, 200)
      assert is_binary(body["auth_url"])
      assert is_binary(body["state_key"])
      assert body["auth_url"] =~ "ctrl-client-id"
    end

    test "requires authentication", %{conn: conn} do
      conn = post(conn, "/api/providers/oauth/start", %{provider_type: @bypass_provider})
      assert conn.status in [401, 403]
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/providers/oauth/status/:state_key
  # ---------------------------------------------------------------------------

  describe "GET /api/providers/oauth/status/:state_key" do
    test "returns 404 for an unknown state key", %{conn: conn, authed: authed} do
      conn =
        conn
        |> authed.()
        |> get("/api/providers/oauth/status/totally-unknown-key")

      assert json_response(conn, 404)["error"] =~ "not found"
    end

    test "returns pending status for a fresh flow", %{conn: conn, authed: authed} do
      start_conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: @bypass_provider})

      %{"state_key" => state_key} = json_response(start_conn, 200)

      status_conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> authed.()
        |> get("/api/providers/oauth/status/#{state_key}")

      assert json_response(status_conn, 200)["status"] == "pending"
    end

    test "returns completed status after successful callback", %{
      conn: conn,
      authed: authed,
      bypass: bypass
    } do
      # Set up Bypass to return a successful token exchange
      Bypass.expect_once(bypass, "POST", "/token", fn bconn ->
        body =
          Jason.encode!(%{
            access_token: "ctrl-access-tok",
            token_type: "Bearer",
            expires_in: 3600
          })

        bconn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, body)
      end)

      # Start flow and exchange code
      start_conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: @bypass_provider})

      %{"state_key" => state_key} = json_response(start_conn, 200)

      # Simulate the OAuth callback
      {:ok, _provider} = ProviderOAuth.handle_callback("auth-code", state_key)

      # Poll status — should be completed now
      status_conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> authed.()
        |> get("/api/providers/oauth/status/#{state_key}")

      body = json_response(status_conn, 200)
      assert body["status"] == "completed"
      assert body["provider"] != nil
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/providers/oauth/status/some-key")
      assert conn.status in [401, 403]
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/providers/oauth/callback
  # ---------------------------------------------------------------------------

  describe "GET /api/providers/oauth/callback" do
    test "returns 404 HTML for unknown state key", %{conn: conn} do
      conn = get(conn, "/api/providers/oauth/callback?code=abc&state=unknown-key")

      assert conn.status == 404
      assert conn.resp_body =~ "Connection Failed"
    end

    test "returns success HTML after valid token exchange", %{
      conn: conn,
      bypass: bypass,
      user: user
    } do
      Bypass.expect_once(bypass, "POST", "/token", fn bconn ->
        body =
          Jason.encode!(%{
            access_token: "callback-access-tok",
            token_type: "Bearer",
            expires_in: 3600
          })

        bconn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, body)
      end)

      {:ok, %{state_key: state_key}} =
        ProviderOAuth.start_flow(@bypass_provider, user.id)

      conn = get(conn, "/api/providers/oauth/callback?code=valid-code&state=#{state_key}")

      assert conn.status == 200
      assert conn.resp_body =~ "Connected"
    end

    test "returns expired HTML when state is past TTL", %{conn: conn, user: user} do
      {:ok, %{state_key: state_key}} =
        ProviderOAuth.start_flow(@bypass_provider, user.id)

      [{^state_key, entry}] = :ets.lookup(:provider_oauth_states, state_key)
      :ets.insert(:provider_oauth_states, {state_key, Map.put(entry, :expires_at, 0)})

      conn = get(conn, "/api/providers/oauth/callback?code=any&state=#{state_key}")

      assert conn.status == 410
      assert conn.resp_body =~ "Connection Failed"
    end

    test "returns 400 HTML when code or state is missing", %{conn: conn} do
      conn = get(conn, "/api/providers/oauth/callback?code=abc")
      assert conn.status == 400
    end
  end
end
