import Config

config :james,
  ecto_repos: [James.Repo]

config :james, James.Repo,
  adapter: Ecto.Adapters.Postgres

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
