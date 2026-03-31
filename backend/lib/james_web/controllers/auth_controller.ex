defmodule JamesWeb.AuthController do
  use Phoenix.Controller, formats: [:json]

  alias James.{Auth, Accounts, OAuth}

  @frontend_url "http://localhost:4173"

  # GET /api/auth/:provider — redirect browser to OAuth provider
  def oauth_redirect(conn, %{"provider" => provider}) do
    cond do
      not OAuth.supported?(provider) ->
        conn |> put_status(:bad_request) |> json(%{error: "Unknown provider: #{provider}"})

      not OAuth.configured?(provider) ->
        conn
        |> put_status(:not_implemented)
        |> json(%{error: "#{String.capitalize(provider)} OAuth credentials not configured. Set #{String.upcase(provider)}_CLIENT_ID and #{String.upcase(provider)}_CLIENT_SECRET."})

      true ->
        state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
        url = OAuth.authorization_url(provider, state)
        redirect(conn, external: url)
    end
  end

  # GET /api/auth/:provider/callback — handle provider redirect back
  def oauth_callback(conn, %{"provider" => provider, "code" => code}) do
    case OAuth.exchange_code(provider, code) do
      {:ok, %{provider: prov, uid: uid, email: email, name: name}} ->
        user =
          case Accounts.find_or_create_user_by_oauth(prov, uid, %{email: email, name: name}) do
            {:ok, u} -> u
            {:error, _} ->
              # Fallback: try by email (provider may have changed uid representation)
              Accounts.get_user_by_email(email)
          end

        if user do
          {:ok, token} = Auth.generate_token(user)
          {:ok, refresh} = Auth.generate_refresh_token(user)

          # Redirect to frontend callback page with token in query params
          redirect_url = "#{frontend_url()}/auth/callback?token=#{token}&refresh=#{refresh}"
          redirect(conn, external: redirect_url)
        else
          error_url = "#{frontend_url()}/login?error=account_error"
          redirect(conn, external: error_url)
        end

      {:error, reason} ->
        error_url = "#{frontend_url()}/login?error=#{URI.encode(reason)}"
        redirect(conn, external: error_url)
    end
  end

  def oauth_callback(conn, %{"provider" => provider, "error" => error}) do
    error_url = "#{frontend_url()}/login?error=#{URI.encode("#{provider}: #{error}")}"
    redirect(conn, external: error_url)
  end

  # POST /api/auth/dev_login — dev-only bypass
  def dev_login(conn, %{"email" => email} = params) do
    name = Map.get(params, "name", email)

    user =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, user} = Accounts.create_user(%{email: email, name: name})
          user

        user ->
          user
      end

    with {:ok, token} <- Auth.generate_token(user),
         {:ok, refresh} <- Auth.generate_refresh_token(user) do
      conn
      |> put_status(:ok)
      |> json(%{token: token, refresh_token: refresh, user: user_json(user)})
    end
  end

  def dev_login(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "email required"})
  end

  # POST /api/auth/refresh
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    with {:ok, claims} <- Auth.verify_refresh_token(refresh_token),
         user when not is_nil(user) <- Accounts.get_user(claims["sub"]),
         {:ok, token} <- Auth.generate_token(user),
         {:ok, new_refresh} <- Auth.generate_refresh_token(user) do
      conn |> json(%{token: token, refresh_token: new_refresh})
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid refresh token"})
    end
  end

  # POST /api/auth/logout
  def logout(conn, _params) do
    conn |> json(%{ok: true})
  end

  # GET /api/auth/me
  def me(conn, _params) do
    user = conn.assigns.current_user
    conn |> json(%{user: user_json(user)})
  end

  # POST /api/auth/device-code — generate a new device code pair
  def device_code(conn, _params) do
    alias James.Auth.DeviceCode

    case DeviceCode.generate_code() do
      {:ok, result} ->
        json(conn, %{
          device_code: result.device_code,
          user_code: result.user_code,
          verification_uri: "#{frontend_url()}/auth/device",
          expires_in: result.expires_in,
          interval: result.interval
        })

      {:error, _} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "failed to generate code"})
    end
  end

  # POST /api/auth/device-code/verify — user approves the code in browser
  def device_code_verify(conn, %{"user_code" => user_code}) do
    alias James.Auth.DeviceCode
    user = conn.assigns.current_user

    case DeviceCode.verify_code(user_code, user.id) do
      {:ok, _} -> json(conn, %{ok: true, message: "Device authorized."})
      {:error, :invalid_or_expired} -> conn |> put_status(:not_found) |> json(%{error: "Invalid or expired code."})
    end
  end

  # POST /api/auth/device-code/token — client polls for approval
  def device_code_token(conn, %{"device_code" => device_code}) do
    alias James.Auth.DeviceCode

    case DeviceCode.check_code(device_code) do
      {:ok, user_id} ->
        user = Accounts.get_user(user_id)
        {:ok, token} = Auth.generate_token(user)
        json(conn, %{access_token: token, token_type: "bearer"})

      {:error, :pending} ->
        conn |> put_status(428) |> json(%{error: "authorization_pending"})

      {:error, :expired} ->
        conn |> put_status(:gone) |> json(%{error: "expired_token"})

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_grant"})
    end
  end

  defp user_json(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      execution_mode: user.execution_mode || "direct",
      personality_id: user.personality_id
    }
  end

  defp frontend_url do
    Application.get_env(:james, :frontend_url, @frontend_url)
  end
end
