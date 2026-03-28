defmodule James.Repo do
  use Ecto.Repo,
    otp_app: :james,
    adapter: Ecto.Adapters.Postgres
end
