defmodule James.Plugins.Registry do
  @moduledoc "In-memory registry of loaded plugin manifests and their provided skills/commands."

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def register(plugin_id, manifest) do
    Agent.update(__MODULE__, &Map.put(&1, plugin_id, manifest))
  end

  def unregister(plugin_id) do
    Agent.update(__MODULE__, &Map.delete(&1, plugin_id))
  end

  def get(plugin_id) do
    Agent.get(__MODULE__, &Map.get(&1, plugin_id))
  end

  def list_all do
    Agent.get(__MODULE__, & &1)
  end

  def skills_for_plugin(plugin_id) do
    case get(plugin_id) do
      %{"skills" => skills} -> skills
      _ -> []
    end
  end
end
