defmodule JamesWeb.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", JamesWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end
end
