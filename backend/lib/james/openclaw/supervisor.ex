defmodule James.OpenClaw.Supervisor do
  @moduledoc """
  DynamicSupervisor that manages agent worker GenServers.
  Each agent task runs as a child process under this supervisor.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts an agent worker under this supervisor.
  """
  def start_agent(module, opts) do
    spec = {module, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
