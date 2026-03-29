defmodule James.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        James.Repo,
        {Phoenix.PubSub, name: James.PubSub}
      ] ++ endpoint_children()

    opts = [strategy: :one_for_one, name: James.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp endpoint_children do
    if Application.get_env(:james, :skip_endpoint), do: [], else: [JamesWeb.Endpoint]
  end
end
