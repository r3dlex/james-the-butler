defmodule JamesWeb.PluginController do
  use Phoenix.Controller, formats: [:json]

  alias James.Plugins

  def index(conn, _params) do
    user = conn.assigns.current_user
    plugins = Plugins.list_plugins(user.id)
    json(conn, %{plugins: Enum.map(plugins, &plugin_json/1)})
  end

  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "user_id", user.id)

    case Plugins.install_plugin(attrs) do
      {:ok, plugin} ->
        conn |> put_status(:created) |> json(%{plugin: plugin_json(plugin)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def enable(conn, %{"id" => id}) do
    case Plugins.get_plugin(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      plugin ->
        {:ok, updated} = Plugins.enable_plugin(plugin)
        json(conn, %{plugin: plugin_json(updated)})
    end
  end

  def disable(conn, %{"id" => id}) do
    case Plugins.get_plugin(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      plugin ->
        {:ok, updated} = Plugins.disable_plugin(plugin)
        json(conn, %{plugin: plugin_json(updated)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Plugins.get_plugin(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      plugin ->
        {:ok, _} = Plugins.uninstall_plugin(plugin)
        json(conn, %{ok: true})
    end
  end

  defp plugin_json(p) do
    %{
      id: p.id,
      name: p.name,
      version: p.version,
      manifest: p.manifest,
      enabled: p.enabled,
      inserted_at: p.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
