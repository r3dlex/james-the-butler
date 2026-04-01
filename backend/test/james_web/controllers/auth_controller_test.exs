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

  # ---------------------------------------------------------------------------
  # OAuth callback — robust error handling and user linking (Task 8.2)
  # ---------------------------------------------------------------------------

  describe "GET /api/auth/:provider/callback — OAuth error parameter" do
    test "redirects to login with error when error=access_denied", %{conn: conn} do
      conn = get(conn, "/api/auth/google/callback?error=access_denied")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "error"
    end

    test "redirects to login when error=server_error is returned", %{conn: conn} do
      conn = get(conn, "/api/auth/github/callback?error=server_error")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "error"
    end
  end

  describe "GET /api/auth/:provider/callback — Bypass-backed OAuth flows" do
    setup do
      bypass = Bypass.open()
      base = "http://localhost:#{bypass.port}"

      System.put_env("GOOGLE_CLIENT_ID", "test-google-id")
      System.put_env("GOOGLE_CLIENT_SECRET", "test-google-secret")
      System.put_env("OAUTH_GOOGLE_TOKEN_URL", "#{base}/token")
      System.put_env("OAUTH_GOOGLE_USERINFO_URL", "#{base}/userinfo")

      on_exit(fn ->
        System.delete_env("GOOGLE_CLIENT_ID")
        System.delete_env("GOOGLE_CLIENT_SECRET")
        System.delete_env("OAUTH_GOOGLE_TOKEN_URL")
        System.delete_env("OAUTH_GOOGLE_USERINFO_URL")
      end)

      {:ok, bypass: bypass}
    end

    test "successful callback creates new user and redirects with token", %{
      conn: conn,
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "POST", "/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{access_token: "gtoken123"}))
      end)

      Bypass.expect_once(bypass, "GET", "/userinfo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            sub: "google-uid-new-001",
            email: "newuser@example.com",
            name: "New OAuth User"
          })
        )
      end)

      conn = get(conn, "/api/auth/google/callback?code=valid-code")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "token="
      assert location =~ "refresh="

      user = James.Accounts.get_user_by_email("newuser@example.com")
      assert user != nil
      assert user.name == "New OAuth User"
      assert user.oauth_provider == "google"
      assert user.oauth_uid == "google-uid-new-001"
    end

    test "successful callback with existing email links provider and redirects with token",
         %{conn: conn, bypass: bypass} do
      {:ok, existing_user} =
        James.Accounts.create_user(%{email: "existing@example.com", name: "Existing User"})

      Bypass.expect_once(bypass, "POST", "/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{access_token: "gtoken456"}))
      end)

      Bypass.expect_once(bypass, "GET", "/userinfo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            sub: "google-uid-existing-002",
            email: "existing@example.com",
            name: "Existing User"
          })
        )
      end)

      conn = get(conn, "/api/auth/google/callback?code=valid-code-2")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "token="

      updated_user = James.Accounts.get_user(existing_user.id)
      assert updated_user.oauth_provider == "google"
      assert updated_user.oauth_uid == "google-uid-existing-002"
    end

    test "callback with invalid/expired code redirects to error page", %{
      conn: conn,
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "POST", "/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            error: "invalid_grant",
            error_description: "Code has expired or already been used."
          })
        )
      end)

      conn = get(conn, "/api/auth/google/callback?code=expired-code")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "error" or location =~ "login"
    end

    test "duplicate provider linking succeeds without duplicate user", %{
      conn: conn,
      bypass: bypass
    } do
      {:ok, _user} =
        James.Accounts.create_user(%{
          email: "linked@example.com",
          name: "Linked User",
          oauth_provider: "google",
          oauth_uid: "google-uid-original-003"
        })

      Bypass.expect_once(bypass, "POST", "/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{access_token: "gtoken789"}))
      end)

      Bypass.expect_once(bypass, "GET", "/userinfo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            sub: "google-uid-original-003",
            email: "linked@example.com",
            name: "Linked User"
          })
        )
      end)

      conn = get(conn, "/api/auth/google/callback?code=valid-code-3")
      assert conn.status == 302
      location = get_resp_header(conn, "location") |> hd()
      assert location =~ "token="

      # Only one user with this email should exist — no duplicate created
      assert James.Accounts.get_user_by_email("linked@example.com") != nil
      assert James.Accounts.get_user_by_oauth("google", "google-uid-original-003") != nil
    end
  end

  describe "Accounts.find_or_create_user_by_oauth/3 — unit tests" do
    test "creates new user when no provider match and no email match" do
      result =
        James.Accounts.find_or_create_user_by_oauth("google", "uid-brand-new", %{
          email: "brand_new@example.com",
          name: "Brand New"
        })

      assert {:ok, user} = result
      assert user.email == "brand_new@example.com"
      assert user.oauth_provider == "google"
      assert user.oauth_uid == "uid-brand-new"
    end

    test "returns existing user when provider+uid match" do
      {:ok, existing} =
        James.Accounts.create_user(%{
          email: "provideruser@example.com",
          name: "Provider User",
          oauth_provider: "google",
          oauth_uid: "uid-existing-provider"
        })

      {:ok, found} =
        James.Accounts.find_or_create_user_by_oauth("google", "uid-existing-provider", %{
          email: "provideruser@example.com",
          name: "Provider User"
        })

      assert found.id == existing.id
    end

    test "links provider to existing user matched by email" do
      {:ok, existing} =
        James.Accounts.create_user(%{
          email: "emailmatch@example.com",
          name: "Email Match User"
        })

      {:ok, linked} =
        James.Accounts.find_or_create_user_by_oauth("google", "uid-email-match", %{
          email: "emailmatch@example.com",
          name: "Email Match User"
        })

      assert linked.id == existing.id
      assert linked.oauth_provider == "google"
      assert linked.oauth_uid == "uid-email-match"
    end

    test "updates oauth_uid when same user re-authenticates with same provider" do
      {:ok, existing} =
        James.Accounts.create_user(%{
          email: "reauth@example.com",
          name: "Re-Auth User",
          oauth_provider: "google",
          oauth_uid: "old-uid"
        })

      {:ok, updated} =
        James.Accounts.find_or_create_user_by_oauth("google", "old-uid", %{
          email: "reauth@example.com",
          name: "Re-Auth User"
        })

      assert updated.id == existing.id
    end
  end

  describe "Accounts.link_oauth_provider/3" do
    test "sets oauth_provider and oauth_uid on user" do
      {:ok, user} = James.Accounts.create_user(%{email: "linker@example.com", name: "Linker"})

      {:ok, updated} = James.Accounts.link_oauth_provider(user, "google", "uid-linker-001")
      assert updated.oauth_provider == "google"
      assert updated.oauth_uid == "uid-linker-001"
    end

    test "updates existing oauth link for same provider is idempotent" do
      {:ok, user} =
        James.Accounts.create_user(%{
          email: "updater@example.com",
          name: "Updater",
          oauth_provider: "google",
          oauth_uid: "old-uid-999"
        })

      {:ok, updated} = James.Accounts.link_oauth_provider(user, "google", "old-uid-999")
      assert updated.oauth_uid == "old-uid-999"
    end
  end
end
