import Config

config :james, James.Repo,
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5433")),
  database: System.get_env("DB_DATABASE", "james_test#{System.get_env("MIX_TEST_PARTITION")}"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Don't start a real HTTP server in tests — use Phoenix.ConnTest dispatch instead
config :james, JamesWeb.Endpoint, server: false

# Disable Oban in tests
config :james, Oban, testing: :inline

# Print only warnings and errors during test
config :logger, level: :warning

# Use mock LLM provider in tests to avoid real API calls
config :james, :llm_provider, James.Test.MockLLMProvider
