defmodule James.Workers.HostHealthWorkerTest do
  use James.DataCase

  alias James.Workers.HostHealthWorker

  describe "perform/1" do
    test "runs without error" do
      job = %Oban.Job{args: %{}}
      assert :ok = HostHealthWorker.perform(job)
    end

    test "completes even when no hosts are registered" do
      job = %Oban.Job{args: %{}}
      assert :ok = HostHealthWorker.perform(job)
    end
  end
end
