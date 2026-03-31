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
end
