defmodule James.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :james,
    adapter: Ecto.Adapters.Postgres
end
