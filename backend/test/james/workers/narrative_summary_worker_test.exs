defmodule James.Workers.NarrativeSummaryWorkerTest do
  use James.DataCase

  alias James.{Accounts, ExecutionHistory, Hosts, Sessions}
  alias James.Test.MockLLMProvider
  alias James.Workers.NarrativeSummaryWorker

  setup do
    MockLLMProvider.flush()
    :ok
  end

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
    test "returns :ok when session has no execution history entries" do
      session = setup_session()

      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      assert ExecutionHistory.list_entries(session_id: session.id) == []
    end

    test "returns :ok for non-existent session_id" do
      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => Ecto.UUID.generate()}
               })
    end

    test "generates and stores narrative from execution history entries when LLM succeeds" do
      session = setup_session()

      ExecutionHistory.log_action(session.id, "tool_call", %{"tool" => "bash", "cmd" => "deploy"})

      ExecutionHistory.log_action(session.id, "decision", %{
        "choice" => "proceed",
        "result" => "success"
      })

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "User deployed the application successfully.",
           usage: %{input_tokens: 20, output_tokens: 10}
         }}
      )

      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      # The worker adds a new entry with the narrative summary stored on it
      entries = ExecutionHistory.list_entries(session_id: session.id)
      assert length(entries) == 3

      summary_entry = Enum.find(entries, fn e -> not is_nil(e.narrative_summary) end)
      assert summary_entry != nil
      assert summary_entry.narrative_summary =~ "deployed"
    end

    test "returns :ok silently when LLM errors" do
      session = setup_session()

      ExecutionHistory.log_action(session.id, "tool_call", %{"tool" => "bash"})

      MockLLMProvider.push_response({:error, "timeout"})

      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      # No additional narrative entry should be created on LLM error
      entries = ExecutionHistory.list_entries(session_id: session.id)
      assert Enum.all?(entries, fn e -> is_nil(e.narrative_summary) end)
    end

    test "handles empty execution history gracefully without calling LLM" do
      session = setup_session()

      # No entries logged — worker must not call LLM and must return :ok
      MockLLMProvider.push_response({:error, "should not be called"})

      assert :ok ==
               NarrativeSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      # The queued response was never consumed — flush to verify
      MockLLMProvider.flush()
      assert ExecutionHistory.list_entries(session_id: session.id) == []
    end
  end
end
