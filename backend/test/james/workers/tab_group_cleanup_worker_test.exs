defmodule James.Workers.TabGroupCleanupWorkerTest do
  use James.DataCase

  alias James.Workers.TabGroupCleanupWorker

  describe "perform/1" do
    test "returns :ok" do
      assert :ok == TabGroupCleanupWorker.perform(%Oban.Job{args: %{}})
    end
  end
end
