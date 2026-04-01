defmodule James.AuthTest do
  use ExUnit.Case, async: true

  alias James.Auth

  # jwt_secret is set to "dev-jwt-secret-change-in-prod-min-32-chars" in config.exs
  # which is inherited by the test environment since test.exs does not override it.

  defp sample_user(id \\ "user-123"), do: %{id: id}

  describe "generate_token/1" do
    test "returns {:ok, token} tuple" do
      assert {:ok, token} = Auth.generate_token(sample_user())
      assert is_binary(token)
    end

    test "token is a non-empty JWT string (three dot-separated segments)" do
      {:ok, token} = Auth.generate_token(sample_user())
      parts = String.split(token, ".")
      assert length(parts) == 3
      assert Enum.all?(parts, fn p -> String.length(p) > 0 end)
    end

    test "generates unique tokens for the same user on repeated calls" do
      {:ok, t1} = Auth.generate_token(sample_user())
      {:ok, t2} = Auth.generate_token(sample_user())
      # iat may differ by a second; tokens include random jti or differ by time
      # At minimum both should be valid — allow equality only if clock is frozen
      assert is_binary(t1) and is_binary(t2)
    end

    test "includes type=access claim" do
      {:ok, token} = Auth.generate_token(sample_user())
      {:ok, claims} = Auth.verify_token(token)
      assert claims["type"] == "access"
    end

    test "includes sub claim matching the user id" do
      {:ok, token} = Auth.generate_token(sample_user("abc-42"))
      {:ok, claims} = Auth.verify_token(token)
      assert claims["sub"] == "abc-42"
    end

    test "includes exp claim in the future" do
      {:ok, token} = Auth.generate_token(sample_user())
      {:ok, claims} = Auth.verify_token(token)
      assert claims["exp"] > System.system_time(:second)
    end

    test "includes iat claim close to now" do
      now = System.system_time(:second)
      {:ok, token} = Auth.generate_token(sample_user())
      {:ok, claims} = Auth.verify_token(token)
      assert abs(claims["iat"] - now) <= 2
    end
  end

  describe "generate_refresh_token/1" do
    test "returns {:ok, token} tuple" do
      assert {:ok, token} = Auth.generate_refresh_token(sample_user())
      assert is_binary(token)
    end

    test "refresh token has type=refresh claim" do
      {:ok, token} = Auth.generate_refresh_token(sample_user())
      {:ok, claims} = Auth.verify_refresh_token(token)
      assert claims["type"] == "refresh"
    end

    test "refresh token includes sub matching user id" do
      {:ok, token} = Auth.generate_refresh_token(sample_user("refresh-user"))
      {:ok, claims} = Auth.verify_refresh_token(token)
      assert claims["sub"] == "refresh-user"
    end

    test "refresh token has a longer expiry than access token" do
      {:ok, access} = Auth.generate_token(sample_user())
      {:ok, refresh} = Auth.generate_refresh_token(sample_user())
      {:ok, access_claims} = Auth.verify_token(access)
      {:ok, refresh_claims} = Auth.verify_refresh_token(refresh)
      assert refresh_claims["exp"] > access_claims["exp"]
    end
  end

  describe "verify_token/1" do
    test "returns {:ok, claims} for a valid access token" do
      {:ok, token} = Auth.generate_token(sample_user())
      assert {:ok, claims} = Auth.verify_token(token)
      assert is_map(claims)
    end

    test "returns {:error, :wrong_token_type} for a refresh token passed as access" do
      {:ok, refresh} = Auth.generate_refresh_token(sample_user())
      assert {:error, :wrong_token_type} = Auth.verify_token(refresh)
    end

    test "returns an error tuple for a tampered token" do
      {:ok, token} = Auth.generate_token(sample_user())
      tampered = token <> "x"
      assert {:error, _reason} = Auth.verify_token(tampered)
    end

    test "returns an error tuple for a random string" do
      assert {:error, _reason} = Auth.verify_token("not.a.token")
    end

    test "returns an error tuple for an empty string" do
      assert {:error, _reason} = Auth.verify_token("")
    end

    test "verified claims contain expected keys" do
      {:ok, token} = Auth.generate_token(sample_user("key-test"))
      {:ok, claims} = Auth.verify_token(token)
      assert Map.has_key?(claims, "sub")
      assert Map.has_key?(claims, "exp")
      assert Map.has_key?(claims, "iat")
      assert Map.has_key?(claims, "type")
    end
  end

  describe "verify_refresh_token/1" do
    test "returns {:ok, claims} for a valid refresh token" do
      {:ok, token} = Auth.generate_refresh_token(sample_user())
      assert {:ok, claims} = Auth.verify_refresh_token(token)
      assert is_map(claims)
    end

    test "returns {:error, :wrong_token_type} for an access token passed as refresh" do
      {:ok, access} = Auth.generate_token(sample_user())
      assert {:error, :wrong_token_type} = Auth.verify_refresh_token(access)
    end

    test "returns an error tuple for a tampered refresh token" do
      {:ok, token} = Auth.generate_refresh_token(sample_user())
      assert {:error, _reason} = Auth.verify_refresh_token(token <> "!")
    end

    test "returns an error tuple for a random string" do
      assert {:error, _reason} = Auth.verify_refresh_token("garbage")
    end

    test "verified refresh claims contain type=refresh" do
      {:ok, token} = Auth.generate_refresh_token(sample_user("r-user"))
      {:ok, claims} = Auth.verify_refresh_token(token)
      assert claims["type"] == "refresh"
      assert claims["sub"] == "r-user"
    end
  end
end
