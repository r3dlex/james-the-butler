import Config

config :james, James.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "james_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :james, JamesWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base:
    "dev-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-framework-to-work",
  check_origin: false,
  debug_errors: true,
  code_reloader: false
