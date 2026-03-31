import Config

config :james, James.Repo,
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5433")),
  database: System.get_env("DB_DATABASE", "james_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :james, JamesWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base:
    "dev-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-framework-to-work",
  check_origin: false,
  debug_errors: true,
  code_reloader: false
