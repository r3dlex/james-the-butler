defmodule James.OAuth do
  @moduledoc """
  OAuth 2.0 provider integration for Google, Microsoft, and GitHub.
  Each provider follows the standard authorization code flow.
  """

  @providers %{
    "google" => %{
      auth_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      userinfo_url: "https://www.googleapis.com/oauth2/v3/userinfo",
      scopes: "openid email profile"
    },
    "microsoft" => %{
      auth_url: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
      token_url: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
      userinfo_url: "https://graph.microsoft.com/v1.0/me",
      scopes: "openid email profile User.Read"
    },
    "github" => %{
      auth_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      userinfo_url: "https://api.github.com/user",
      scopes: "read:user user:email"
    }
  }

  # Providers that support PKCE (GitHub does not)
  @pkce_providers ["google", "microsoft"]

  # State token max age in seconds (10 minutes)
  @state_max_age 10 * 60

  @doc """
  Generates a PKCE code verifier and challenge pair.

  Returns `{code_verifier, code_challenge}` where the challenge is the
  base64url-encoded SHA-256 hash of the verifier (S256 method).
  """
  def generate_pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  @doc """
  Generates a signed state token containing a timestamp for CSRF protection.
  """
  def generate_state, do: build_state(System.system_time(:second))

  @doc """
  Generates a signed state token with a specific timestamp (for testing expiry).
  """
  def generate_state_at(timestamp), do: build_state(timestamp)

  @doc """
  Verifies a state token signature and checks it has not expired (10-minute window).

  Returns `:ok`, `{:error, :state_expired}`, or `{:error, :invalid_state}`.
  """
  def verify_state(state) do
    with {:ok, ts} <- decode_state(state) do
      check_state_expiry(ts)
    end
  end

  @doc """
  Builds the provider authorization URL to redirect the browser to.
  Includes PKCE parameters for Google and Microsoft; GitHub is excluded.
  """
  def authorization_url(provider, state) do
    config = Map.fetch!(@providers, provider)
    client_id = client_id!(provider)
    redirect_uri = callback_uri(provider)

    base_params = %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: config.scopes,
      state: state
    }

    params = maybe_add_pkce(base_params, provider)

    "#{config.auth_url}?#{URI.encode_query(params)}"
  end

  @doc """
  Exchanges the authorization code for an access token, then fetches the user profile.
  Returns `{:ok, %{id, email, name, provider}}` or `{:error, reason}`.
  """
  def exchange_code(provider, code) do
    with {:ok, access_token} <- fetch_token(provider, code) do
      fetch_profile(provider, access_token)
    end
  end

  def supported?(provider), do: Map.has_key?(@providers, provider)

  def configured?(provider) do
    not is_nil(client_id(provider)) and not is_nil(client_secret(provider))
  end

  # --- Private ---

  defp token_url(provider) do
    System.get_env("OAUTH_#{String.upcase(provider)}_TOKEN_URL") || @providers[provider].token_url
  end

  defp userinfo_url(provider) do
    System.get_env("OAUTH_#{String.upcase(provider)}_USERINFO_URL") ||
      @providers[provider].userinfo_url
  end

  defp fetch_token("github", code) do
    case Req.post(token_url("github"),
           headers: [{"Accept", "application/json"}],
           form: [
             client_id: client_id!("github"),
             client_secret: client_secret!("github"),
             code: code,
             redirect_uri: callback_uri("github")
           ]
         ) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{body: body}} ->
        {:error, "GitHub token error: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "GitHub token request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_token(provider, code) do
    case Req.post(token_url(provider),
           form: [
             client_id: client_id!(provider),
             client_secret: client_secret!(provider),
             code: code,
             redirect_uri: callback_uri(provider),
             grant_type: "authorization_code"
           ]
         ) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{body: body}} ->
        {:error, "#{provider} token error: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "#{provider} token request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_profile("github", token) do
    case Req.get(userinfo_url("github"),
           headers: [{"Authorization", "Bearer #{token}"}, {"User-Agent", "james-the-butler"}]
         ) do
      {:ok, %{status: 200, body: user}} ->
        email =
          case user["email"] do
            nil -> fetch_github_primary_email(token)
            e -> e
          end

        {:ok,
         %{
           provider: "github",
           uid: to_string(user["id"]),
           email: email,
           name: user["name"] || user["login"]
         }}

      {:ok, %{body: body}} ->
        {:error, "GitHub profile error: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "GitHub profile request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_profile("google", token) do
    case Req.get(userinfo_url("google"),
           headers: [{"Authorization", "Bearer #{token}"}]
         ) do
      {:ok, %{status: 200, body: user}} ->
        {:ok,
         %{
           provider: "google",
           uid: user["sub"],
           email: user["email"],
           name: user["name"]
         }}

      {:ok, %{body: body}} ->
        {:error, "Google profile error: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Google profile request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_profile("microsoft", token) do
    case Req.get(userinfo_url("microsoft"),
           headers: [{"Authorization", "Bearer #{token}"}]
         ) do
      {:ok, %{status: 200, body: user}} ->
        {:ok,
         %{
           provider: "microsoft",
           uid: user["id"],
           email: user["mail"] || user["userPrincipalName"],
           name: user["displayName"]
         }}

      {:ok, %{body: body}} ->
        {:error, "Microsoft profile error: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Microsoft profile request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_github_primary_email(token) do
    emails_url =
      System.get_env("OAUTH_GITHUB_EMAILS_URL", "https://api.github.com/user/emails")

    case Req.get(emails_url,
           headers: [
             {"Authorization", "Bearer #{token}"},
             {"User-Agent", "james-the-butler"}
           ]
         ) do
      {:ok, %{status: 200, body: emails}} when is_list(emails) ->
        primary = Enum.find(emails, fn e -> e["primary"] end)
        primary && primary["email"]

      _ ->
        nil
    end
  end

  defp callback_uri(provider) do
    base = Application.get_env(:james, :base_url, "http://localhost:4000")
    "#{base}/api/auth/#{provider}/callback"
  end

  defp client_id(provider) do
    System.get_env("#{String.upcase(provider)}_CLIENT_ID")
  end

  defp client_id!(provider) do
    client_id(provider) || raise "#{String.upcase(provider)}_CLIENT_ID not set"
  end

  defp client_secret(provider) do
    System.get_env("#{String.upcase(provider)}_CLIENT_SECRET")
  end

  defp client_secret!(provider) do
    client_secret(provider) || raise "#{String.upcase(provider)}_CLIENT_SECRET not set"
  end

  # --- PKCE helpers ---

  defp maybe_add_pkce(params, provider) when provider in @pkce_providers do
    {_verifier, challenge} = generate_pkce()
    Map.merge(params, %{code_challenge: challenge, code_challenge_method: "S256"})
  end

  defp maybe_add_pkce(params, _provider), do: params

  # --- State token helpers ---

  defp state_secret do
    Application.get_env(:james, :jwt_secret, "dev-jwt-secret-change-in-prod-min-32-chars")
  end

  defp build_state(timestamp) do
    payload = Integer.to_string(timestamp)
    nonce = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    data = "#{payload}.#{nonce}"
    sig = sign_state(data)
    Base.url_encode64("#{data}.#{sig}", padding: false)
  end

  defp decode_state(token) do
    with {:ok, decoded} <- safe_decode(token),
         [payload, nonce, sig] <- split_state(decoded),
         data = "#{payload}.#{nonce}",
         true <- valid_signature?(data, sig) do
      parse_timestamp(payload)
    else
      _ -> {:error, :invalid_state}
    end
  end

  defp safe_decode(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, _} = ok -> ok
      :error -> {:error, :invalid_state}
    end
  end

  defp split_state(decoded) do
    case String.split(decoded, ".", parts: 3) do
      [_payload, _nonce, _sig] = parts -> parts
      _ -> nil
    end
  end

  defp sign_state(data) do
    :crypto.mac(:hmac, :sha256, state_secret(), data)
    |> Base.url_encode64(padding: false)
  end

  defp valid_signature?(data, sig), do: sign_state(data) == sig

  defp parse_timestamp(payload) do
    case Integer.parse(payload) do
      {ts, ""} -> {:ok, ts}
      _ -> {:error, :invalid_state}
    end
  end

  defp check_state_expiry(ts) do
    age = System.system_time(:second) - ts

    if age > @state_max_age do
      {:error, :state_expired}
    else
      :ok
    end
  end
end
