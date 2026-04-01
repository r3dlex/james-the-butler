defmodule JamesWeb.ProviderController do
  @moduledoc """
  HTTP controller for provider-related actions:

  - `GET    /api/providers`          — list all configs for the current user
  - `POST   /api/providers`          — create a new provider config
  - `GET    /api/providers/:id`      — show a single provider config
  - `PUT    /api/providers/:id`      — update a provider config
  - `DELETE /api/providers/:id`      — delete a provider config
  - `POST   /api/providers/:id/test`  — test connectivity for a saved provider config
  - `GET    /api/providers/:id/models` — list available models for a saved provider config
  """

  use Phoenix.Controller, formats: [:json]

  alias James.Providers.{ConnectionTester, ModelCatalog}
  alias James.ProviderSettings

  # ---------------------------------------------------------------------------
  # CRUD actions
  # ---------------------------------------------------------------------------

  @doc """
  Lists all provider configs for the authenticated user.

  API keys are masked in the response (e.g. `"sk-...6789"`).
  """
  def index(conn, _params) do
    user = conn.assigns.current_user
    configs = ProviderSettings.list_provider_configs(user)
    json(conn, %{providers: Enum.map(configs, &render_config/1)})
  end

  @doc """
  Creates a new provider config for the authenticated user.

  Returns 201 on success or 422 with error details on validation failure.
  """
  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = build_attrs(params, user.id)

    case ProviderSettings.create_provider_config(attrs) do
      {:ok, config} ->
        full = ProviderSettings.get_provider_config!(config.id)

        conn
        |> put_status(:created)
        |> json(%{provider: render_config(full)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  @doc """
  Shows a single provider config. Returns 404 for other users' configs.

  The API key is masked in the response.
  """
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case fetch_config_for_user(id, user.id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      config ->
        json(conn, %{provider: render_config(config)})
    end
  end

  @doc """
  Updates a provider config. Re-encrypts the API key if it is included in the
  request params. Returns 404 for other users' configs.
  """
  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case fetch_config_for_user(id, user.id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      config ->
        attrs = build_attrs(Map.delete(params, "id"), config.user_id)

        case ProviderSettings.update_provider_config(config, attrs) do
          {:ok, updated} ->
            full = ProviderSettings.get_provider_config!(updated.id)
            json(conn, %{provider: render_config(full)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  @doc """
  Deletes a provider config. Returns 404 for other users' configs.
  """
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case fetch_config_for_user(id, user.id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      config ->
        {:ok, _} = ProviderSettings.delete_provider_config(config)
        json(conn, %{ok: true})
    end
  end

  # ---------------------------------------------------------------------------
  # Existing connection-test and model-listing actions
  # ---------------------------------------------------------------------------

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

  # Builds an atom-keyed attrs map from string-keyed request params.
  # `encrypt_api_key/1` in ProviderSettings mixes in atom keys, so we must
  # start with atom keys to avoid Ecto's mixed-key restriction.
  defp build_attrs(params, user_id) do
    %{
      user_id: user_id,
      provider_type: Map.get(params, "provider_type"),
      display_name: Map.get(params, "display_name"),
      base_url: Map.get(params, "base_url"),
      auth_method: Map.get(params, "auth_method"),
      status: Map.get(params, "status"),
      api_key: Map.get(params, "api_key")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp fetch_config(id) do
    ProviderSettings.get_provider_config!(id)
  rescue
    Ecto.NoResultsError -> nil
  end

  # Fetches a config only when it belongs to the given user_id.
  defp fetch_config_for_user(id, user_id) do
    case fetch_config(id) do
      %{user_id: ^user_id} = config -> config
      _ -> nil
    end
  end

  # Renders a config map with the API key masked.
  defp render_config(config) do
    %{
      id: config.id,
      user_id: config.user_id,
      provider_type: config.provider_type,
      display_name: config.display_name,
      base_url: config.base_url,
      auth_method: config.auth_method,
      status: config.status,
      last_tested_at: config.last_tested_at,
      api_key: mask_api_key(config.decrypted_api_key),
      inserted_at: config.inserted_at,
      updated_at: config.updated_at
    }
  end

  # Masks an API key — keeps the last 4 characters visible.
  # "sk-abc123456789" → "sk-...6789"
  # Returns nil when no key is present.
  defp mask_api_key(nil), do: nil

  defp mask_api_key(key) when byte_size(key) <= 4, do: "...#{key}"

  defp mask_api_key(key) do
    last4 = String.slice(key, -4, 4)
    "sk-...#{last4}"
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, k ->
        opts |> Keyword.get(String.to_existing_atom(k), k) |> to_string()
      end)
    end)
  end
end
