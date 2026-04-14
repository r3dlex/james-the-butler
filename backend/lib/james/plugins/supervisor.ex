defmodule James.Plugins.Supervisor do
  @moduledoc "DynamicSupervisor managing individual plugin GenServer instances."

  use DynamicSupervisor
  require Logger

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Start or get a plugin instance for the given plugin."
  @spec start_plugin(James.Plugins.Plugin.t()) :: {:ok, pid} | {:error, term}
  def start_plugin(%James.Plugins.Plugin{} = plugin) do
    if Process.whereis(__MODULE__) do
      case DynamicSupervisor.start_child(__MODULE__, {James.Plugins.Instance, plugin}) do
        {:ok, pid} = ok ->
          Logger.info("Plugin instance started",
            plugin_id: plugin.id,
            name: plugin.name,
            pid: pid
          )

          ok

        {:error, {:already_started, pid}} ->
          Logger.info("Plugin already running, reusing", plugin_id: plugin.id, pid: pid)
          {:ok, pid}

        other ->
          Logger.error("Failed to start plugin", plugin_id: plugin.id, error: inspect(other))
          other
      end
    else
      Logger.warning("Plugin supervisor not running, skipping instance start",
        plugin_id: plugin.id
      )

      {:error, :supervisor_not_started}
    end
  end

  @doc "Stop a plugin instance by plugin id."
  @spec stop_plugin(Ecto.UUID.t()) :: :ok
  def stop_plugin(plugin_id) do
    if Process.whereis(__MODULE__) do
      case Registry.lookup(James.Plugins.Instance.Registry, plugin_id) do
        [{pid, _}] ->
          DynamicSupervisor.terminate_child(__MODULE__, pid)
          Logger.info("Plugin instance stopped", plugin_id: plugin_id)

        [] ->
          :ok
      end
    else
      :ok
    end
  end
end
