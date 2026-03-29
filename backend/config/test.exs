import Config

config :james, James.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "james_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 10

config :james, skip_endpoint: true

# Print only warnings and errors during test
config :logger, level: :warning
