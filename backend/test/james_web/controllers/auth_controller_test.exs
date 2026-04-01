defmodule JamesWeb.AuthControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Auth}

  describe "POST /api/auth/dev_login" do
    test "creates user and returns token for new email", %{conn: conn} do
      conn = post(conn, "/api/auth/dev_login", %{email: "devnew@example.com", name: "Dev User"})
      body = json_response(conn, 200)
      assert Map.has_key?(body, "token")
      assert Map.has_key?(body, "refresh_token")
      assert body["user"]["email"] == "devnew@example.com"
    end

    test "returns existing user token for known email", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "devexisting@example.com", name: "Existing"})
      conn = post(conn, "/api/auth/dev_login", %{email: user.email})
      body = json_response(conn, 200)
      assert body["user"]["id"] == user.id
    end

    test "returns 400 when email is missing", %{conn: conn} do
      conn = post(conn, "/api/auth/dev_login", %{})
      assert json_response(conn, 400)["error"] == "email required"
    end

    test "user response includes execution_mode field", %{conn: conn} do
      conn = post(conn, "/api/auth/dev_login", %{email: "mode@example.com"})
      user = json_response(conn, 200)["user"]
      assert Map.has_key?(user, "execution_mode")
    end
  end

  describe "POST /api/auth/refresh" do
    test "issues new tokens for a valid refresh token", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "refresh@example.com"})
      {:ok, refresh} = Auth.generate_refresh_token(user)
      conn = post(conn, "/api/auth/refresh", %{refresh_token: refresh})
      body = json_response(conn, 200)
      assert Map.has_key?(body, "token")
      assert Map.has_key?(body, "refresh_token")
    end

    test "returns 401 for an invalid refresh token", %{conn: conn} do
      conn = post(conn, "/api/auth/refresh", %{refresh_token: "not-a-real-token"})
      assert json_response(conn, 401)["error"] =~ "invalid"
    end

    test "returns 401 for an access token used as refresh token", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "wrongtype@example.com"})
      {:ok, access} = Auth.generate_token(user)
      conn = post(conn, "/api/auth/refresh", %{refresh_token: access})
      assert json_response(conn, 401)["error"] =~ "invalid"
    end
  end

  describe "POST /api/auth/logout" do
    test "returns ok when authenticated", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "logout@example.com"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/auth/logout", %{})
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = post(conn, "/api/auth/logout", %{})
      assert conn.status == 401
    end
  end

  describe "GET /api/auth/me" do
    test "returns current user info", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "me@example.com", name: "Me"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/auth/me")
      body = json_response(conn, 200)
      assert body["user"]["email"] == "me@example.com"
      assert body["user"]["name"] == "Me"
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, "/api/auth/me")
      assert conn.status == 401
    end

    test "user response includes id, email, name, execution_mode, personality_id", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "mefields@example.com"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/auth/me")
      u = json_response(conn, 200)["user"]
      assert Map.has_key?(u, "id")
      assert Map.has_key?(u, "email")
      assert Map.has_key?(u, "name")
      assert Map.has_key?(u, "execution_mode")
      assert Map.has_key?(u, "personality_id")
    end
  end

  describe "GET /api/auth/:provider (oauth_redirect)" do
    test "returns 400 for unsupported provider", %{conn: conn} do
      conn = get(conn, "/api/auth/unknown_provider")
      assert json_response(conn, 400)["error"] =~ "Unknown provider"
    end

    test "returns 501 for unconfigured but supported provider", %{conn: conn} do
      # google is supported but likely not configured in test env
      conn = get(conn, "/api/auth/google")
      # Either 501 (not configured) or a redirect if env vars are set
      assert conn.status in [501, 302]
    end
  end

  describe "POST /api/auth/device-code" do
    test "returns a device code pair", %{conn: conn} do
      conn = post(conn, "/api/auth/device-code", %{})
      body = json_response(conn, 200)
      assert Map.has_key?(body, "device_code")
      assert Map.has_key?(body, "user_code")
      assert Map.has_key?(body, "expires_in")
    end
  end

  describe "POST /api/auth/device-code/verify" do
    test "returns 401 when not authenticated", %{conn: conn} do
      conn = post(conn, "/api/auth/device-code/verify", %{user_code: "ABCD-1234"})
      assert conn.status == 401
    end

    test "returns 404 for invalid user code", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "verify@example.com"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/auth/device-code/verify", %{user_code: "INVALID-CODE"})
      assert json_response(conn, 404)["error"] =~ "Invalid"
    end
  end
end
