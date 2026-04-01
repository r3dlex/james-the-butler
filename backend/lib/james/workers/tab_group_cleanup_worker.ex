defmodule James.Workers.TabGroupCleanupWorker do
  @moduledoc """
  Oban worker that closes idle browser tab groups.
  A tab group is considered idle when no activity has occurred for 24 hours.
  Scheduled to run periodically via Oban's cron plugin.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 3

  alias James.Browser.CdpManager

  # 24 hours in seconds
  @idle_threshold_seconds 86_400

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@idle_threshold_seconds, :second)
    CdpManager.close_idle_tab_groups(cutoff)
    :ok
  end
end
