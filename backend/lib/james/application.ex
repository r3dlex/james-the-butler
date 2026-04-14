defmodule James.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach OpenTelemetry instrumentation before starting any supervised
    # processes so that events emitted during startup are captured.
    James.Telemetry.setup()

    children = children_for_env()

    opts = [strategy: :one_for_one, name: James.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children_for_env do
    case Mix.env() do
      :test ->
        [
          James.Repo,
          {Task.Supervisor, name: James.TaskSupervisor},
          {Phoenix.PubSub, name: James.PubSub},
          JamesWeb.Endpoint
        ]

      _ ->
        [
          James.Repo,
          {Task.Supervisor, name: James.TaskSupervisor},
          {Phoenix.PubSub, name: James.PubSub},
          {Oban, Application.fetch_env!(:james, Oban)},
          James.OpenClaw.Supervisor,
          James.OpenClaw.Orchestrator,
          # James.Browser.CDPConnectionPool,  # removed: module does not exist
          James.Planner.MetaPlanner,
          James.Channels.TURNCredentials,
          James.Providers.ProviderOAuth,
          James.Plugins.Registry,
          James.Agents.Tools.Registry,
          {Registry, keys: :unique, name: James.Plugins.Instance.Registry},
          James.Plugins.Supervisor,
          {Registry, keys: :unique, name: James.MCP.Server.Registry},
          James.MCP.Supervisor,
          James.Skills,
          {James.Skills.Bridge, export_dir: System.user_home() <> "/.claude/skills"},
          {James.Skills.Watcher, dir: System.user_home() <> "/.claude/skills"},
          JamesWeb.Endpoint
        ]
    end
  end
end
