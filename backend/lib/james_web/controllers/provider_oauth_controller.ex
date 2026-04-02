defmodule JamesWeb.ProviderOAuthController do
  @moduledoc """
  HTTP endpoints for the OAuth 2.0 PKCE provider connection flow.

  Endpoints
    POST /api/providers/oauth/start         — start a new PKCE flow
    GET  /api/providers/oauth/callback      — receives the authorization code redirect
    GET  /api/providers/oauth/status/:key   — frontend polls until :completed
  """

  use JamesWeb, :controller

  alias James.Providers.ProviderOAuth

  # ── POST /api/providers/oauth/start ──────────────────────────────────────────

  def start(conn, %{"provider_type" => provider_type}) do
    user_id = conn.assigns[:current_user].id

    case ProviderOAuth.start_flow(provider_type, user_id) do
      {:ok, %{auth_url: auth_url, state_key: state_key}} ->
        json(conn, %{auth_url: auth_url, state_key: state_key})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def start(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "provider_type is required"})
  end

  # ── GET /api/providers/oauth/callback ────────────────────────────────────────

  def callback(conn, %{"code" => code, "state" => state_key}) do
    case ProviderOAuth.handle_callback(code, state_key) do
      {:ok, _provider_config} ->
        # Close the popup / redirect to a success page
        html(conn, success_html())

      {:error, :state_not_found} ->
        conn
        |> put_status(:not_found)
        |> html(error_html("OAuth session not found or expired. Please try again."))

      {:error, :state_expired} ->
        conn
        |> put_status(:gone)
        |> html(error_html("OAuth session expired. Please start the flow again."))

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> html(error_html("Authorization failed: #{inspect(reason)}"))
    end
  end

  def callback(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> html(error_html("Missing code or state parameter."))
  end

  # ── GET /api/providers/oauth/status/:state_key ───────────────────────────────

  def status(conn, %{"state_key" => state_key}) do
    case ProviderOAuth.get_status(state_key) do
      {:ok, :completed, provider} ->
        json(conn, %{status: "completed", provider: provider_to_map(provider)})

      {:ok, :pending} ->
        json(conn, %{status: "pending"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "State not found or expired"})
    end
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp provider_to_map(nil), do: nil

  defp provider_to_map(p) do
    %{
      id: p.id,
      provider_type: p.provider_type,
      display_name: p.display_name,
      auth_method: p.auth_method,
      status: p.status
    }
  end

  defp success_html do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Connected — James the Butler</title>
      <style>
        body { font-family: -apple-system, sans-serif; display: flex; align-items: center;
               justify-content: center; min-height: 100vh; margin: 0;
               background: #0d1b2a; color: #e0e0e0; }
        .card { text-align: center; padding: 2rem; }
        h1 { color: #c9a84c; margin-bottom: 0.5rem; }
        p  { color: #8b9ab3; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>✓ Connected</h1>
        <p>You can close this window. James the Butler is now connected.</p>
      </div>
      <script>
        // Auto-close the popup after a short delay
        setTimeout(() => window.close(), 2000);
      </script>
    </body>
    </html>
    """
  end

  defp error_html(message) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Connection Error — James the Butler</title>
      <style>
        body { font-family: -apple-system, sans-serif; display: flex; align-items: center;
               justify-content: center; min-height: 100vh; margin: 0;
               background: #0d1b2a; color: #e0e0e0; }
        .card { text-align: center; padding: 2rem; max-width: 400px; }
        h1 { color: #e05252; margin-bottom: 0.5rem; }
        p  { color: #8b9ab3; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>Connection Failed</h1>
        <p>#{message}</p>
        <p>You can close this window.</p>
      </div>
    </body>
    </html>
    """
  end
end
