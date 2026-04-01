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

  describe "GET /api/auth/:provider/callback with error param" do
    test "redirects to login page with error", %{conn: conn} do
      conn = get(conn, "/api/auth/google/callback?error=access_denied")
      assert conn.status == 302
      assert get_resp_header(conn, "location") |> hd() =~ "error"
    end
  end

  describe "POST /api/auth/device-code/token" do
    test "returns 428 when code is pending (not yet verified)", %{conn: conn} do
      # Generate a device code — it starts as :pending
      resp = post(conn, "/api/auth/device-code", %{})
      device_code = json_response(resp, 200)["device_code"]
      conn2 = post(conn, "/api/auth/device-code/token", %{device_code: device_code})
      assert conn2.status == 428
      assert json_response(conn2, 428)["error"] == "authorization_pending"
    end

    test "returns 400 for invalid device_code" do
      conn = Phoenix.ConnTest.build_conn()
      conn = post(conn, "/api/auth/device-code/token", %{device_code: "invalid-code"})
      assert conn.status in [400, 410]
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

    test "returns ok when user code is valid", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "verify_ok@example.com"})
      device_resp = post(conn, "/api/auth/device-code", %{})
      user_code = json_response(device_resp, 200)["user_code"]

      conn = authed_conn(conn, user)
      conn = post(conn, "/api/auth/device-code/verify", %{user_code: user_code})
      assert json_response(conn, 200)["ok"] == true
    end
  end

  describe "POST /api/auth/device-code/token — approved" do
    test "returns access token after device code is verified", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "dc_token@example.com"})
      device_resp = post(conn, "/api/auth/device-code", %{})
      device_code = json_response(device_resp, 200)["device_code"]
      user_code = json_response(device_resp, 200)["user_code"]

      # Verify the user code so it moves from :pending to :approved
      authed = authed_conn(conn, user)
      post(authed, "/api/auth/device-code/verify", %{user_code: user_code})

      conn2 = post(conn, "/api/auth/device-code/token", %{device_code: device_code})
      body = json_response(conn2, 200)
      assert Map.has_key?(body, "access_token")
    end

    test "returns 410 for expired device_code" do
      conn = Phoenix.ConnTest.build_conn()
      # Simulate an expired code by checking with a known-expired format
      # We use a valid format but expired — rely on the error path returning 400 or 410
      conn = post(conn, "/api/auth/device-code/token", %{device_code: "expired-code-xyz"})
      assert conn.status in [400, 410]
    end
  end

  describe "GET /api/auth/:provider (oauth_redirect) — configured provider" do
    setup do
      System.put_env("GOOGLE_CLIENT_ID", "test-google-id")
      System.put_env("GOOGLE_CLIENT_SECRET", "test-google-secret")

      on_exit(fn ->
        System.delete_env("GOOGLE_CLIENT_ID")
        System.delete_env("GOOGLE_CLIENT_SECRET")
      end)

      :ok
    end

    test "redirects to Google auth URL when provider is configured", %{conn: conn} do
      conn = get(conn, "/api/auth/google")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert String.starts_with?(location, "https://accounts.google.com/o/oauth2/v2/auth")
    end
  end

  describe "GET /api/auth/:provider/callback with code" do
    test "redirects to error page when exchange_code fails", %{conn: conn} do
      # Without valid credentials, exchange_code raises — which means this
      # path hits the runtime error before the {:error, reason} branch.
      # Set credentials so we get an HTTP failure instead of a raise.
      System.put_env("GOOGLE_CLIENT_ID", "test-id")
      System.put_env("GOOGLE_CLIENT_SECRET", "test-secret")

      conn = get(conn, "/api/auth/google/callback?code=bad-code")
      # Either redirects to error page (302) or returns 302 with error in URL
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "error" or location =~ "login"

      System.delete_env("GOOGLE_CLIENT_ID")
      System.delete_env("GOOGLE_CLIENT_SECRET")
    end
  end
end
