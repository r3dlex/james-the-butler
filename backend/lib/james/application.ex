defmodule James.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      James.Repo,
      {Phoenix.PubSub, name: James.PubSub},
      JamesWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: James.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
