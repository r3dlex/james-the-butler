defmodule James.Workers.NarrativeSummaryWorkerTest do
  use James.DataCase

  alias James.{Accounts, ExecutionHistory, Hosts, Sessions}
  alias James.Workers.NarrativeSummaryWorker

  defp setup_session do
    {:ok, user} = Accounts.create_user(%{email: "nsw_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "nsw-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9900"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "NSW Session"})

    session
  end

  describe "perform/1" do
    test "returns :ok when session has fewer than 2 messages" do
      session = setup_session()

      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      assert ExecutionHistory.list_entries(session_id: session.id) == []
    end

    test "returns :ok when ANTHROPIC_API_KEY is not set" do
      session = setup_session()

      Sessions.create_message(%{session_id: session.id, role: "user", content: "Hello"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Hi!"})

      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })
    end

    test "returns :ok for non-existent session_id" do
      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => Ecto.UUID.generate()}
               })
    end
  end
end
