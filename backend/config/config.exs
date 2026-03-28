import Config

config :james,
  ecto_repos: [James.Repo]

config :james, James.Repo, adapter: Ecto.Adapters.Postgres

config :james, JamesWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  pubsub_server: James.PubSub

# Configures the Phoenix JSON library
config :phoenix, :json_library, Jason

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
