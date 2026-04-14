defmodule James.Plugins.Instance do
  @moduledoc """
  GenServer representing a single loaded plugin instance.

  Loads the plugin manifest, registers its tools with the Tools Registry,
  registers skills, and sets up hook handlers.
  """

  use GenServer
  require Logger

  alias James.Agents.Tools.Registry, as: ToolsRegistry
  alias James.Plugins.{Loader, Sandbox}

  @registry James.Plugins.Instance.Registry

  def start_link(%James.Plugins.Plugin{} = plugin) do
    name = {:via, Registry, {@registry, plugin.id}}
    GenServer.start_link(__MODULE__, plugin, name: name)
  end

  @impl true
  def init(%James.Plugins.Plugin{} = plugin) do
    state = %{
      plugin: plugin,
      tools: [],
      registered_tools: []
    }

    {:ok, state, {:continue, :load_plugin}}
  end

  @impl true
  def handle_continue(:load_plugin, state) do
    case Loader.load_plugin(state.plugin) do
      {:ok, plugin_state} ->
        # Register tools
        registered = register_tools(plugin_state.tools, state.plugin.id)
        # Update plugin last_active_at
        James.Plugins.touch_plugin(state.plugin.id)
        new_state = %{state | tools: plugin_state.tools, registered_tools: registered}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Plugin load failed",
          plugin_id: state.plugin.id,
          name: state.plugin.name,
          reason: inspect(reason)
        )

        {:stop, {:shutdown, reason}, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Plugin instance terminating",
      plugin_id: state.plugin.id,
      reason: inspect(reason)
    )

    # Unregister all tools for this plugin
    Enum.each(state.registered_tools, fn tool_name ->
      ToolsRegistry.unregister(tool_name)
    end)

    :ok
  end

  @doc "Get the list of tools registered by this plugin."
  def tools(plugin_id) do
    case Registry.lookup(@registry, plugin_id) do
      [{pid, _}] -> GenServer.call(pid, :get_tools)
      [] -> nil
    end
  end

  @doc "Execute a plugin tool by name."
  def call_tool(plugin_id, tool_name, arguments) do
    case Registry.lookup(@registry, plugin_id) do
      [{pid, _}] -> GenServer.call(pid, {:call_tool, tool_name, arguments})
      [] -> {:error, :plugin_not_running}
    end
  end

  @impl true
  def handle_call(:get_tools, _from, state) do
    {:reply, state.tools, state}
  end

  @impl true
  def handle_call({:call_tool, tool_name, arguments}, _from, state) do
    result = Sandbox.execute_tool(state.plugin.id, tool_name, arguments, state.tools)
    {:reply, result, state}
  end

  # --- Private ---

  defp register_tools(tools, plugin_id) when is_list(tools) do
    Enum.map(tools, fn tool ->
      # Prefix tool name with plugin id to avoid collisions
      full_name = "plugin__#{plugin_id}__#{tool["name"]}"

      definition = %{
        name: full_name,
        description: tool["description"] || "",
        input_schema: tool["input_schema"] || %{},
        plugin_id: plugin_id
      }

      ToolsRegistry.register(definition)
      full_name
    end)
  end

  defp register_tools(_, _), do: []
end
