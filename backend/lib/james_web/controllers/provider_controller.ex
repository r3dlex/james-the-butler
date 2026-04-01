defmodule JamesWeb.ProviderController do
  @moduledoc """
  HTTP controller for provider-related actions:

  - `POST /api/providers/:id/test`  — test connectivity for a saved provider config
  - `GET  /api/providers/:id/models` — list available models for a saved provider config
  """

  use Phoenix.Controller, formats: [:json]

  alias James.Providers.{ConnectionTester, ModelCatalog}
  alias James.ProviderSettings

  @doc """
  Tests the connection for the provider config identified by `:id`.

  Returns 200 with `%{"status" => "connected", "latency_ms" => integer}` on
  success, or 200 with `%{"status" => "failed", "reason" => string}` on
  failure.  Returns 404 when the config does not exist.
  """
  def test_connection(conn, %{"id" => id}) do
    config = fetch_config(id)

    if is_nil(config) do
      conn |> put_status(:not_found) |> json(%{error: "not found"})
    else
      case ConnectionTester.test_connection(config) do
        {:ok, %{status: :connected, latency_ms: ms}} ->
          json(conn, %{status: "connected", latency_ms: ms})

        {:error, %{status: :failed, reason: reason}} ->
          json(conn, %{status: "failed", reason: reason})
      end
    end
  end

  @doc """
  Returns the list of models available for the provider config identified by
  `:id`.

  For cloud providers the list is hardcoded.  For local providers the running
  server is queried.  Returns 404 when the config does not exist.
  """
  def list_models(conn, %{"id" => id}) do
    config = fetch_config(id)

    if is_nil(config) do
      conn |> put_status(:not_found) |> json(%{error: "not found"})
    else
      result =
        case config.provider_type do
          type when type in ~w(ollama lm_studio openai_compatible) ->
            ModelCatalog.list_models(type, config.base_url || "")

          type ->
            ModelCatalog.list_models(type)
        end

      case result do
        {:ok, models} ->
          json(conn, %{models: models})

        {:error, reason} ->
          conn |> put_status(:bad_gateway) |> json(%{error: reason})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fetch_config(id) do
    ProviderSettings.get_provider_config!(id)
  rescue
    Ecto.NoResultsError -> nil
  end
end
