defmodule James.Agents.Tools.Registry do
  @moduledoc """
  Agent that tracks all dynamically registered tools from MCP servers and plugins.

  Tools are registered with a unique name and can be looked up by agents
  when building their tool list.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Register a tool definition (%{name, description, input_schema})."
  @spec register(map()) :: :ok
  def register(tool_definition) do
    Agent.update(__MODULE__, &Map.put(&1, tool_definition.name, tool_definition))
  end

  @doc "Unregister a tool by name."
  @spec unregister(String.t()) :: :ok
  def unregister(name) do
    Agent.update(__MODULE__, &Map.delete(&1, name))
  end

  @doc "List all registered tools as a map."
  @spec list_all() :: %{String.t() => map()}
  def list_all do
    Agent.get(__MODULE__, & &1)
  end

  @doc "Get a single tool by name."
  @spec get(String.t()) :: map() | nil
  def get(name) do
    Agent.get(__MODULE__, &Map.get(&1, name))
  end

  @doc "List all tool definitions as a list (for agent tool merging)."
  @spec to_list() :: [map()]
  def to_list do
    Agent.get(__MODULE__, &Map.values(&1))
  end

  @doc "Clear all registered tools."
  @spec clear() :: :ok
  def clear do
    Agent.update(__MODULE__, fn _ -> %{} end)
  end
end
