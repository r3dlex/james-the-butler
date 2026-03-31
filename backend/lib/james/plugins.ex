defmodule James.Plugins do
  @moduledoc "Manages plugin lifecycle: install, enable, disable, uninstall."

  import Ecto.Query
  alias James.Repo
  alias James.Plugins.Plugin

  def list_plugins(user_id) do
    from(p in Plugin, where: p.user_id == ^user_id, order_by: [asc: p.name])
    |> Repo.all()
  end

  def get_plugin(id), do: Repo.get(Plugin, id)

  def install_plugin(attrs) do
    %Plugin{}
    |> Plugin.changeset(attrs)
    |> Repo.insert()
  end

  def enable_plugin(%Plugin{} = plugin) do
    plugin |> Plugin.changeset(%{enabled: true}) |> Repo.update()
  end

  def disable_plugin(%Plugin{} = plugin) do
    plugin |> Plugin.changeset(%{enabled: false}) |> Repo.update()
  end

  def uninstall_plugin(%Plugin{} = plugin) do
    Repo.delete(plugin)
  end

  def list_enabled_plugins(user_id) do
    from(p in Plugin, where: p.user_id == ^user_id and p.enabled == true)
    |> Repo.all()
  end
end
