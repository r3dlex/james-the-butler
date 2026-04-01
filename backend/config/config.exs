import Config

config :james,
  ecto_repos: [James.Repo],
  jwt_secret: System.get_env("JWT_SECRET", "dev-jwt-secret-change-in-prod-min-32-chars"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  base_url: System.get_env("BASE_URL", "http://localhost:4000"),
  frontend_url: System.get_env("FRONTEND_URL", "http://localhost:4173"),
  llm_provider: James.Providers.Anthropic

config :james, James.Repo,
  adapter: Ecto.Adapters.Postgres,
  types: James.PostgresTypes

config :james, JamesWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  pubsub_server: James.PubSub

config :james, Oban,
  repo: James.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", James.Workers.HostHealthWorker}
     ]}
  ],
  queues: [default: 10, memory: 5, summaries: 3]

# Configures the Phoenix JSON library
config :phoenix, :json_library, Jason

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
