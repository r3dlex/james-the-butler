defmodule James.Workers.HostHealthWorker do
  @moduledoc "Periodic worker that checks health of all registered hosts."

  use Oban.Worker, queue: :default, max_attempts: 1

  alias James.Hosts.Cluster

  @impl Oban.Worker
  def perform(_job) do
    Cluster.health_check_all()
    :ok
  end
end
