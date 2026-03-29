import Config

config :james, James.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "james_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 10

config :james, JamesWeb.Endpoint,
  secret_key_base: "test-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-to-accept-it",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning
