defmodule JamesWeb.ProviderOAuthControllerTest do
  @moduledoc """
  Integration tests for the provider OAuth endpoints.

  The ProviderOAuth GenServer is started once per test suite.
  Tests are NOT async because they share the named GenServer / ETS table.
  """

  use JamesWeb.ConnCase, async: false

  alias James.{Accounts, Auth}
  alias James.Providers.ProviderOAuth

  setup_all do
    case GenServer.whereis(ProviderOAuth) do
      nil -> start_supervised!(ProviderOAuth)
      _pid -> :already_running
    end

    :ok
  end

  setup do
    {:ok, user} =
      Accounts.create_user(%{email: "oauth_ctrl_#{System.unique_integer()}@example.com"})
    {:ok, token} = Auth.generate_token(user)

    authed = fn conn ->
      put_req_header(conn, "authorization", "Bearer #{token}")
    end

    {:ok, user: user, authed: authed}
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
      System.delete_env("OPENAI_CODEX_CLIENT_ID")

      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: "openai_codex"})

      assert json_response(conn, 422)["error"] =~ "OPENAI_CODEX_CLIENT_ID"
    end

    test "returns 400 when provider_type is missing", %{conn: conn, authed: authed} do
      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{})

      assert json_response(conn, 400)["error"] =~ "provider_type"
    end

    test "returns auth_url and state_key when client_id is present", %{conn: conn, authed: authed} do
      System.put_env("OPENAI_CLIENT_ID", "ctrl-test-id")
      on_exit(fn -> System.delete_env("OPENAI_CLIENT_ID") end)

      conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: "openai"})

      body = json_response(conn, 200)
      assert is_binary(body["auth_url"])
      assert is_binary(body["state_key"])
      assert body["auth_url"] =~ "ctrl-test-id"
    end

    test "requires authentication", %{conn: conn} do
      conn = post(conn, "/api/providers/oauth/start", %{provider_type: "openai"})
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
      System.put_env("OPENAI_CLIENT_ID", "ctrl-test-id")
      on_exit(fn -> System.delete_env("OPENAI_CLIENT_ID") end)

      start_conn =
        conn
        |> authed.()
        |> post("/api/providers/oauth/start", %{provider_type: "openai"})

      %{"state_key" => state_key} = json_response(start_conn, 200)

      status_conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> authed.()
        |> get("/api/providers/oauth/status/#{state_key}")

      assert json_response(status_conn, 200)["status"] == "pending"
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

    test "returns 400 HTML when code or state is missing", %{conn: conn} do
      conn = get(conn, "/api/providers/oauth/callback?code=abc")
      assert conn.status == 400
    end
  end
end
