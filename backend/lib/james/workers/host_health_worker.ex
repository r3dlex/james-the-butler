defmodule James.Workers.HostHealthWorker do
  @moduledoc "Periodic worker that checks health of all registered hosts."

  use Oban.Worker, queue: :default, max_attempts: 1

  @impl Oban.Worker
  def perform(_job) do
    James.Hosts.Cluster.health_check_all()
    :ok
  end
end
