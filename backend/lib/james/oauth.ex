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

  @doc """
  Builds the provider authorization URL to redirect the browser to.
  """
  def authorization_url(provider, state) do
    config = Map.fetch!(@providers, provider)
    client_id = client_id!(provider)
    redirect_uri = callback_uri(provider)

    params =
      URI.encode_query(%{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: config.scopes,
        state: state
      })

    "#{config.auth_url}?#{params}"
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

  defp fetch_token("github", code) do
    config = @providers["github"]

    case Req.post(config.token_url,
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
    config = @providers[provider]

    case Req.post(config.token_url,
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
    config = @providers["github"]

    case Req.get(config.userinfo_url,
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
    config = @providers["google"]

    case Req.get(config.userinfo_url,
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
    config = @providers["microsoft"]

    case Req.get(config.userinfo_url,
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
    case Req.get("https://api.github.com/user/emails",
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
end
