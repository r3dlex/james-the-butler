defmodule James.Auth do
  @moduledoc """
  JWT token generation and verification for API auth.
  """

  use Joken.Config

  @token_ttl 60 * 60  # 1 hour in seconds
  @refresh_ttl 30 * 24 * 60 * 60  # 30 days

  def token_config do
    default_claims(skip: [:iss, :aud])
  end

  def generate_token(%{id: user_id} = _user) do
    claims = %{
      "sub" => user_id,
      "exp" => System.system_time(:second) + @token_ttl,
      "iat" => System.system_time(:second),
      "type" => "access"
    }

    case generate_and_sign(claims, signer()) do
      {:ok, token, _} -> {:ok, token}
      error -> error
    end
  end

  def generate_refresh_token(%{id: user_id} = _user) do
    claims = %{
      "sub" => user_id,
      "exp" => System.system_time(:second) + @refresh_ttl,
      "iat" => System.system_time(:second),
      "type" => "refresh"
    }

    case generate_and_sign(claims, signer()) do
      {:ok, token, _} -> {:ok, token}
      error -> error
    end
  end

  def verify_token(token) do
    case verify_and_validate(token, signer()) do
      {:ok, claims} ->
        if claims["type"] == "access" do
          {:ok, claims}
        else
          {:error, :wrong_token_type}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_refresh_token(token) do
    case verify_and_validate(token, signer()) do
      {:ok, claims} ->
        if claims["type"] == "refresh" do
          {:ok, claims}
        else
          {:error, :wrong_token_type}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp signer do
    Joken.Signer.create("HS256", jwt_secret())
  end

  defp jwt_secret do
    Application.fetch_env!(:james, :jwt_secret)
  end
end
