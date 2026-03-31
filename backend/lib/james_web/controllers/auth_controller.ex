defmodule JamesWeb.AuthController do
  use Phoenix.Controller, formats: [:json]

  alias James.{Auth, Accounts}

  # POST /api/auth/login
  # Accepts OAuth provider + code, returns JWT + refresh token.
  # For dev: accepts email directly.
  def login(conn, %{"provider" => provider, "code" => _code} = _params) do
    # In production this would exchange the OAuth code with the provider.
    # For now we return an error directing clients to use dev login.
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "OAuth provider '#{provider}' not configured. Use /api/auth/dev_login."})
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing provider or code"})
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
    conn
    |> put_status(:bad_request)
    |> json(%{error: "email required"})
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
    # Stateless JWTs — client drops the token. Refresh token revocation
    # can be added via a blocklist table in a future iteration.
    conn |> json(%{ok: true})
  end

  # GET /api/auth/me
  def me(conn, _params) do
    user = conn.assigns.current_user
    conn |> json(%{user: user_json(user)})
  end

  # POST /api/auth/device-code — device authorization flow for Office/Chrome clients
  def device_code(conn, _params) do
    # Placeholder — full OAuth device flow requires a persistent code store.
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "Device code flow not yet implemented"})
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
end
