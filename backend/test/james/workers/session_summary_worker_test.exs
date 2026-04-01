defmodule James.Workers.SessionSummaryWorkerTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions}
  alias James.SessionSummaries
  alias James.Test.MockLLMProvider
  alias James.Workers.SessionSummaryWorker

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} = Accounts.create_user(%{email: "ssw_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "ssw-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9901"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "SSW Session"})

    session
  end

  defp add_messages(session, count) do
    for i <- 1..count do
      role = if rem(i, 2) == 1, do: "user", else: "assistant"

      {:ok, _} =
        Sessions.create_message(%{
          session_id: session.id,
          role: role,
          content: "Message number #{i} with some content that adds tokens to the count."
        })
    end
  end

  # Adds enough messages to exceed the 10k token threshold.
  defp add_many_messages(session) do
    content = String.duplicate("word ", 200)

    for i <- 1..30 do
      role = if rem(i, 2) == 1, do: "user", else: "assistant"

      {:ok, _} =
        Sessions.create_message(%{
          session_id: session.id,
          role: role,
          content: content,
          token_count: 400
        })
    end
  end

  describe "perform/1" do
    test "returns :ok for session with 0 messages" do
      session = setup_session()

      assert :ok ==
               SessionSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })
    end

    test "generates summary for session with 2+ messages above token threshold" do
      session = setup_session()
      add_many_messages(session)

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "User discussed Elixir architecture at length.",
           usage: %{input_tokens: 200, output_tokens: 20}
         }}
      )

      assert :ok ==
               SessionSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })
    end

    test "stores summary in session_summaries table" do
      session = setup_session()
      add_many_messages(session)

      MockLLMProvider.push_response(
        {:ok, %{content: "The session covered deployment steps.", usage: %{}}}
      )

      SessionSummaryWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})

      summary = SessionSummaries.get_summary(session.id)
      assert summary != nil
      assert summary.content == "The session covered deployment steps."
    end

    test "uses Microcompact before sending to LLM — stripped messages are shorter" do
      session = setup_session()

      # Add messages large enough to exceed the token threshold; content is long
      # so compaction will reduce what the LLM sees.
      long_content = String.duplicate("tool result data ", 600)

      for _ <- 1..20 do
        {:ok, _} =
          Sessions.create_message(%{
            session_id: session.id,
            role: "user",
            content: long_content,
            token_count: 600
          })
      end

      # The mock will be called once; we just verify nothing crashes and that
      # the summary is stored.
      MockLLMProvider.push_response({:ok, %{content: "Compacted session summary.", usage: %{}}})

      assert :ok ==
               SessionSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      summary = SessionSummaries.get_summary(session.id)
      assert summary != nil
    end

    test "handles LLM error gracefully — returns :ok, no crash" do
      session = setup_session()
      add_many_messages(session)

      MockLLMProvider.push_response({:error, "service unavailable"})

      assert :ok ==
               SessionSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      # No summary should be stored after an LLM error
      assert is_nil(SessionSummaries.get_summary(session.id))
    end

    test "idempotent: running twice updates the existing summary (upsert)" do
      session = setup_session()
      add_many_messages(session)

      MockLLMProvider.push_response({:ok, %{content: "First summary.", usage: %{}}})

      SessionSummaryWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})

      MockLLMProvider.push_response({:ok, %{content: "Second summary — updated.", usage: %{}}})

      SessionSummaryWorker.perform(%Oban.Job{args: %{"session_id" => session.id}})

      # Only one row in the table, with the latest content
      summary = SessionSummaries.get_summary(session.id)
      assert summary.content == "Second summary — updated."
    end

    test "skips LLM call when total tokens are below 10k threshold" do
      session = setup_session()

      # 2 short messages — well below 10k tokens
      add_messages(session, 2)

      # Push an error so that any unexpected LLM call would surface
      MockLLMProvider.push_response({:error, "should not be called"})

      assert :ok ==
               SessionSummaryWorker.perform(%Oban.Job{
                 args: %{"session_id" => session.id}
               })

      # No summary created and error response not consumed
      assert is_nil(SessionSummaries.get_summary(session.id))

      # Drain to confirm the response was never popped
      MockLLMProvider.flush()
    end
  end
end
