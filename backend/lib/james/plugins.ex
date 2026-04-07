defmodule James.Plugins do
  @moduledoc "Manages plugin lifecycle: install, enable, disable, uninstall."

  import Ecto.Query
  alias James.Plugins.Plugin
  alias James.Repo
  alias James.Plugins.Supervisor, as: PluginSupervisor
  alias James.Plugins.Instance

  def list_plugins(user_id) do
    from(p in Plugin, where: p.user_id == ^user_id, order_by: [asc: p.name])
    |> Repo.all()
  end

  def get_plugin(id), do: Repo.get(Plugin, id)

  def install_plugin(attrs) do
    attrs
    |> normalize_string_keys()
    |> Map.put_new("installed_at", DateTime.utc_now())

    %Plugin{}
    |> Plugin.changeset(attrs)
    |> Repo.insert()
  end

  defp normalize_string_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), normalize_string_keys(v)} end)
  end

  defp normalize_string_keys(list) when is_list(list) do
    Enum.map(list, &normalize_string_keys/1)
  end

  defp normalize_string_keys(val), do: val

  def enable_plugin(%Plugin{} = plugin) do
    with {:ok, updated} <- plugin |> Plugin.changeset(%{enabled: true}) |> Repo.update() do
      # Start the plugin instance - return updated even if instance fails
      PluginSupervisor.start_plugin(updated)
      {:ok, updated}
    end
  end

  def disable_plugin(%Plugin{} = plugin) do
    # Stop the plugin instance if running
    PluginSupervisor.stop_plugin(plugin.id)
    plugin |> Plugin.changeset(%{enabled: false}) |> Repo.update()
  end

  def uninstall_plugin(%Plugin{} = plugin) do
    PluginSupervisor.stop_plugin(plugin.id)
    Repo.delete(plugin)
  end

  def list_enabled_plugins(user_id) do
    from(p in Plugin, where: p.user_id == ^user_id and p.enabled == true)
    |> Repo.all()
  end

  @doc "Update last_active_at timestamp for a plugin."
  def touch_plugin(plugin_id) do
    case get_plugin(plugin_id) do
      nil ->
        :ok

      plugin ->
        Repo.update(Ecto.Changeset.change(plugin, %{"last_active_at" => DateTime.utc_now()}))
    end
  end

  @doc "Get all tools registered by a specific plugin."
  def tools_for_plugin(plugin_id) do
    case Instance.tools(plugin_id) do
      nil -> []
      tools -> tools
    end
  end
end
