import Config

config :james, James.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "james_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
