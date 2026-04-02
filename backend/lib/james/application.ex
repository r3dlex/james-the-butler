defmodule James.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach OpenTelemetry instrumentation before starting any supervised
    # processes so that events emitted during startup are captured.
    if Mix.env() != :test, do: James.Telemetry.setup()

    children = children_for_env()

    opts = [strategy: :one_for_one, name: James.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children_for_env do
    case Mix.env() do
      :test ->
        [
          James.Repo,
          {Phoenix.PubSub, name: James.PubSub},
          JamesWeb.Endpoint
        ]

      _ ->
        [
          James.Repo,
          {Phoenix.PubSub, name: James.PubSub},
          {Oban, Application.fetch_env!(:james, Oban)},
          James.OpenClaw.Supervisor,
          James.OpenClaw.Orchestrator,
          James.Planner.MetaPlanner,
          James.Providers.ProviderOAuth,
          James.Plugins.Registry,
          JamesWeb.Endpoint
        ]
    end
  end
end
