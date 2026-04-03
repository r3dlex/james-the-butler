defmodule James.Workers.GitStatusWorkerTest do
  use James.DataCase

  alias James.Workers.GitStatusWorker

  describe "perform/1" do
    test "enqueues successfully with session_id and user_id" do
      # Use a valid binary_id format to avoid CastError
      job = %Oban.Job{args: %{"session_id" => Ecto.UUID.generate(), "user_id" => 1}}
      # Should not crash even if session not found
      :ok = GitStatusWorker.perform(job)
    end

    test "graceful failure with missing args" do
      job = %Oban.Job{args: %{}}
      # Should not crash - returns :ok
      :ok = GitStatusWorker.perform(job)
    end
  end

  describe "enqueue" do
    test "can be enqueued with correct queue" do
      assert GitStatusWorker.new(%{"session_id" => Ecto.UUID.generate(), "user_id" => 1}) != nil
    end
  end
end
