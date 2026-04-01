defmodule James.OAuthTest do
  use ExUnit.Case, async: false

  alias James.OAuth

  # Keys potentially set by a real environment — clear them before and restore after
  # each test so we have a clean slate.
  @google_id_key "GOOGLE_CLIENT_ID"
  @google_secret_key "GOOGLE_CLIENT_SECRET"
  @github_id_key "GITHUB_CLIENT_ID"
  @github_secret_key "GITHUB_CLIENT_SECRET"
  @microsoft_id_key "MICROSOFT_CLIENT_ID"
  @microsoft_secret_key "MICROSOFT_CLIENT_SECRET"

  @all_env_keys [
    @google_id_key,
    @google_secret_key,
    @github_id_key,
    @github_secret_key,
    @microsoft_id_key,
    @microsoft_secret_key
  ]

  setup do
    # Snapshot current values so we can restore them after each test
    original =
      Map.new(@all_env_keys, fn key -> {key, System.get_env(key)} end)

    # Clear all OAuth env vars for a predictable baseline
    Enum.each(@all_env_keys, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(original, fn
        {key, nil} -> System.delete_env(key)
        {key, val} -> System.put_env(key, val)
      end)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # supported?/1
  # ---------------------------------------------------------------------------

  describe "supported?/1" do
    test "returns true for google" do
      assert OAuth.supported?("google") == true
    end

    test "returns true for github" do
      assert OAuth.supported?("github") == true
    end

    test "returns true for microsoft" do
      assert OAuth.supported?("microsoft") == true
    end

    test "returns false for an unknown provider" do
      assert OAuth.supported?("facebook") == false
    end

    test "returns false for an empty string" do
      assert OAuth.supported?("") == false
    end

    test "returns false for a nil-like atom string" do
      assert OAuth.supported?("nil") == false
    end

    test "is case-sensitive — uppercase Google is not supported" do
      assert OAuth.supported?("Google") == false
    end
  end

  # ---------------------------------------------------------------------------
  # configured?/1
  # ---------------------------------------------------------------------------

  describe "configured?/1" do
    test "returns false for google when env vars are absent" do
      assert OAuth.configured?("google") == false
    end

    test "returns false for github when env vars are absent" do
      assert OAuth.configured?("github") == false
    end

    test "returns false for microsoft when env vars are absent" do
      assert OAuth.configured?("microsoft") == false
    end

    test "returns false when only client_id is set for google" do
      System.put_env(@google_id_key, "my-google-client-id")
      assert OAuth.configured?("google") == false
    end

    test "returns false when only client_secret is set for google" do
      System.put_env(@google_secret_key, "my-google-secret")
      assert OAuth.configured?("google") == false
    end

    test "returns true for google when both id and secret are set" do
      System.put_env(@google_id_key, "my-google-client-id")
      System.put_env(@google_secret_key, "my-google-secret")
      assert OAuth.configured?("google") == true
    end

    test "returns true for github when both id and secret are set" do
      System.put_env(@github_id_key, "my-github-client-id")
      System.put_env(@github_secret_key, "my-github-secret")
      assert OAuth.configured?("github") == true
    end

    test "returns true for microsoft when both id and secret are set" do
      System.put_env(@microsoft_id_key, "my-ms-client-id")
      System.put_env(@microsoft_secret_key, "my-ms-secret")
      assert OAuth.configured?("microsoft") == true
    end
  end

  # ---------------------------------------------------------------------------
  # authorization_url/2
  # ---------------------------------------------------------------------------

  describe "authorization_url/2" do
    setup do
      # Set env vars so authorization_url/2 doesn't raise on client_id!
      System.put_env(@google_id_key, "test-google-id")
      System.put_env(@github_id_key, "test-github-id")
      System.put_env(@microsoft_id_key, "test-ms-id")
      :ok
    end

    test "google URL starts with the correct base auth URL" do
      url = OAuth.authorization_url("google", "state123")
      assert String.starts_with?(url, "https://accounts.google.com/o/oauth2/v2/auth")
    end

    test "github URL starts with the correct base auth URL" do
      url = OAuth.authorization_url("github", "state456")
      assert String.starts_with?(url, "https://github.com/login/oauth/authorize")
    end

    test "microsoft URL starts with the correct base auth URL" do
      url = OAuth.authorization_url("microsoft", "state789")
      assert String.starts_with?(url, "https://login.microsoftonline.com")
    end

    test "google URL includes the client_id query param" do
      url = OAuth.authorization_url("google", "s1")
      assert url =~ "client_id=test-google-id"
    end

    test "github URL includes the client_id query param" do
      url = OAuth.authorization_url("github", "s2")
      assert url =~ "client_id=test-github-id"
    end

    test "google URL includes response_type=code" do
      url = OAuth.authorization_url("google", "s1")
      assert url =~ "response_type=code"
    end

    test "google URL includes the state parameter" do
      url = OAuth.authorization_url("google", "my-csrf-state")
      assert url =~ "state=my-csrf-state"
    end

    test "github URL includes the state parameter" do
      url = OAuth.authorization_url("github", "github-state")
      assert url =~ "state=github-state"
    end

    test "google URL includes openid scope" do
      url = OAuth.authorization_url("google", "s")
      assert url =~ "scope="
      decoded = URI.decode_query(URI.parse(url).query)
      assert decoded["scope"] =~ "openid"
    end

    test "github URL includes read:user scope" do
      url = OAuth.authorization_url("github", "s")
      decoded = URI.decode_query(URI.parse(url).query)
      assert decoded["scope"] =~ "read:user"
    end

    test "google URL includes the redirect_uri with the callback path" do
      url = OAuth.authorization_url("google", "s")
      decoded = URI.decode_query(URI.parse(url).query)
      assert decoded["redirect_uri"] =~ "/api/auth/google/callback"
    end

    test "github URL includes the redirect_uri with the callback path" do
      url = OAuth.authorization_url("github", "s")
      decoded = URI.decode_query(URI.parse(url).query)
      assert decoded["redirect_uri"] =~ "/api/auth/github/callback"
    end

    test "raises when client_id env var is not set for a known provider" do
      System.delete_env(@google_id_key)

      assert_raise RuntimeError, ~r/GOOGLE_CLIENT_ID not set/, fn ->
        OAuth.authorization_url("google", "state")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # exchange_code/2 — error paths
  # The OAuth module's provider URLs are hardcoded compile-time constants.
  # In test env the HTTP requests fail immediately (connection refused/DNS),
  # which exercises the {:error, reason} code paths.
  # ---------------------------------------------------------------------------

  describe "exchange_code/2 — raises when credentials missing" do
    test "raises RuntimeError for google when client_id is not set" do
      assert_raise RuntimeError, ~r/GOOGLE_CLIENT_ID not set/, fn ->
        OAuth.exchange_code("google", "some-code")
      end
    end

    test "raises RuntimeError for google when client_secret is not set" do
      System.put_env(@google_id_key, "test-id")

      assert_raise RuntimeError, ~r/GOOGLE_CLIENT_SECRET not set/, fn ->
        OAuth.exchange_code("google", "some-code")
      end
    end

    test "raises RuntimeError for github when client_id is not set" do
      assert_raise RuntimeError, ~r/GITHUB_CLIENT_ID not set/, fn ->
        OAuth.exchange_code("github", "some-code")
      end
    end

    test "raises RuntimeError for github when client_secret is not set" do
      System.put_env(@github_id_key, "test-id")

      assert_raise RuntimeError, ~r/GITHUB_CLIENT_SECRET not set/, fn ->
        OAuth.exchange_code("github", "some-code")
      end
    end

    test "raises RuntimeError for microsoft when client_id is not set" do
      assert_raise RuntimeError, ~r/MICROSOFT_CLIENT_ID not set/, fn ->
        OAuth.exchange_code("microsoft", "some-code")
      end
    end

    test "raises RuntimeError for microsoft when client_secret is not set" do
      System.put_env(@microsoft_id_key, "test-id")

      assert_raise RuntimeError, ~r/MICROSOFT_CLIENT_SECRET not set/, fn ->
        OAuth.exchange_code("microsoft", "some-code")
      end
    end
  end

  describe "exchange_code/2 — network failure returns error" do
    # With credentials set, the requests go out to real provider URLs.
    # In the test environment (no internet/provider), the HTTP call fails
    # immediately with a connection error, exercising the {:error, _} clause.

    test "returns {:error, _} for google when HTTP call fails" do
      System.put_env(@google_id_key, "test-id")
      System.put_env(@google_secret_key, "test-secret")

      assert {:error, reason} = OAuth.exchange_code("google", "bad-code")
      assert is_binary(reason)
    end

    test "returns {:error, _} for github when HTTP call fails" do
      System.put_env(@github_id_key, "test-id")
      System.put_env(@github_secret_key, "test-secret")

      assert {:error, reason} = OAuth.exchange_code("github", "bad-code")
      assert is_binary(reason)
    end

    test "returns {:error, _} for microsoft when HTTP call fails" do
      System.put_env(@microsoft_id_key, "test-id")
      System.put_env(@microsoft_secret_key, "test-secret")

      assert {:error, reason} = OAuth.exchange_code("microsoft", "bad-code")
      assert is_binary(reason)
    end
  end

  # ---------------------------------------------------------------------------
  # exchange_code/2 — with Bypass (token + profile flows)
  # ---------------------------------------------------------------------------

  describe "exchange_code/2 — with Bypass (google)" do
    setup do
      bypass = Bypass.open()
      base = "http://localhost:#{bypass.port}"
      System.put_env(@google_id_key, "test-google-id")
      System.put_env(@google_secret_key, "test-google-secret")
      System.put_env("OAUTH_GOOGLE_TOKEN_URL", "#{base}/google/token")
      System.put_env("OAUTH_GOOGLE_USERINFO_URL", "#{base}/google/userinfo")

      on_exit(fn ->
        System.delete_env("OAUTH_GOOGLE_TOKEN_URL")
        System.delete_env("OAUTH_GOOGLE_USERINFO_URL")
      end)

      {:ok, bypass: bypass}
    end

    test "returns user profile on successful exchange", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/google/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "tok-123"}))
      end)

      Bypass.expect_once(bypass, "GET", "/google/userinfo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"sub" => "g-uid-1", "email" => "g@example.com", "name" => "G User"})
        )
      end)

      assert {:ok, profile} = OAuth.exchange_code("google", "auth-code")
      assert profile.provider == "google"
      assert profile.email == "g@example.com"
      assert profile.uid == "g-uid-1"
    end

    test "returns error when token request returns no access_token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/google/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"error" => "invalid_grant"}))
      end)

      assert {:error, reason} = OAuth.exchange_code("google", "bad-code")
      assert reason =~ "token error"
    end

    test "returns error when userinfo request fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/google/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "tok-abc"}))
      end)

      Bypass.expect_once(bypass, "GET", "/google/userinfo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "unauthorized"}))
      end)

      assert {:error, reason} = OAuth.exchange_code("google", "auth-code")
      assert reason =~ "profile error"
    end
  end

  describe "exchange_code/2 — with Bypass (github)" do
    setup do
      bypass = Bypass.open()
      base = "http://localhost:#{bypass.port}"
      System.put_env(@github_id_key, "test-github-id")
      System.put_env(@github_secret_key, "test-github-secret")
      System.put_env("OAUTH_GITHUB_TOKEN_URL", "#{base}/github/token")
      System.put_env("OAUTH_GITHUB_USERINFO_URL", "#{base}/github/user")
      System.put_env("OAUTH_GITHUB_EMAILS_URL", "#{base}/github/emails")

      on_exit(fn ->
        System.delete_env("OAUTH_GITHUB_TOKEN_URL")
        System.delete_env("OAUTH_GITHUB_USERINFO_URL")
        System.delete_env("OAUTH_GITHUB_EMAILS_URL")
      end)

      {:ok, bypass: bypass}
    end

    test "returns profile with email in user response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/github/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "gh-tok-1"}))
      end)

      Bypass.expect_once(bypass, "GET", "/github/user", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => 42,
            "login" => "ghuser",
            "name" => "GitHub User",
            "email" => "gh@example.com"
          })
        )
      end)

      assert {:ok, profile} = OAuth.exchange_code("github", "gh-code")
      assert profile.provider == "github"
      assert profile.email == "gh@example.com"
    end

    test "fetches primary email when user email is null", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/github/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "gh-tok-2"}))
      end)

      Bypass.expect_once(bypass, "GET", "/github/user", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"id" => 99, "login" => "noemail", "name" => "No Email", "email" => nil})
        )
      end)

      Bypass.expect_once(bypass, "GET", "/github/emails", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{"email" => "secondary@example.com", "primary" => false},
            %{"email" => "primary@example.com", "primary" => true}
          ])
        )
      end)

      assert {:ok, profile} = OAuth.exchange_code("github", "gh-code")
      assert profile.email == "primary@example.com"
    end

    test "returns nil email when emails endpoint fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/github/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "gh-tok-3"}))
      end)

      Bypass.expect_once(bypass, "GET", "/github/user", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => 77,
            "login" => "failmail",
            "name" => "Fail Mail",
            "email" => nil
          })
        )
      end)

      # Use stub (0+ calls allowed) and 404 (not retried by Req)
      Bypass.stub(bypass, "GET", "/github/emails", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "not found"}))
      end)

      assert {:ok, profile} = OAuth.exchange_code("github", "gh-code")
      assert is_nil(profile.email)
    end

    test "returns error when github token response has no access_token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/github/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"error" => "bad_verification_code"}))
      end)

      assert {:error, reason} = OAuth.exchange_code("github", "bad")
      assert reason =~ "GitHub token error"
    end

    test "returns error when github profile request fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/github/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "gh-tok-4"}))
      end)

      Bypass.expect_once(bypass, "GET", "/github/user", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Forbidden"}))
      end)

      assert {:error, reason} = OAuth.exchange_code("github", "gh-code")
      assert reason =~ "GitHub profile error"
    end
  end

  describe "exchange_code/2 — with Bypass (microsoft)" do
    setup do
      bypass = Bypass.open()
      base = "http://localhost:#{bypass.port}"
      System.put_env(@microsoft_id_key, "test-ms-id")
      System.put_env(@microsoft_secret_key, "test-ms-secret")
      System.put_env("OAUTH_MICROSOFT_TOKEN_URL", "#{base}/ms/token")
      System.put_env("OAUTH_MICROSOFT_USERINFO_URL", "#{base}/ms/me")

      on_exit(fn ->
        System.delete_env("OAUTH_MICROSOFT_TOKEN_URL")
        System.delete_env("OAUTH_MICROSOFT_USERINFO_URL")
      end)

      {:ok, bypass: bypass}
    end

    test "returns profile with displayName and mail", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/ms/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "ms-tok-1"}))
      end)

      Bypass.expect_once(bypass, "GET", "/ms/me", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => "ms-uid-1",
            "displayName" => "MS User",
            "mail" => "ms@example.com",
            "userPrincipalName" => "ms@tenant.onmicrosoft.com"
          })
        )
      end)

      assert {:ok, profile} = OAuth.exchange_code("microsoft", "ms-code")
      assert profile.provider == "microsoft"
      assert profile.email == "ms@example.com"
      assert profile.uid == "ms-uid-1"
    end

    test "falls back to userPrincipalName when mail is nil", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/ms/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "ms-tok-2"}))
      end)

      Bypass.expect_once(bypass, "GET", "/ms/me", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => "ms-uid-2",
            "displayName" => "MS User 2",
            "mail" => nil,
            "userPrincipalName" => "ms2@tenant.onmicrosoft.com"
          })
        )
      end)

      assert {:ok, profile} = OAuth.exchange_code("microsoft", "ms-code")
      assert profile.email == "ms2@tenant.onmicrosoft.com"
    end

    test "returns error when microsoft profile request fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/ms/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "ms-tok-3"}))
      end)

      Bypass.expect_once(bypass, "GET", "/ms/me", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "InvalidAuthenticationToken"}))
      end)

      assert {:error, reason} = OAuth.exchange_code("microsoft", "ms-code")
      assert reason =~ "Microsoft profile error"
    end
  end
end
