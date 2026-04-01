defmodule James.Workers.SessionSummaryWorker do
  @moduledoc """
  Oban worker that generates a condensed summary for a session and upserts it
  into the `session_summaries` table.

  The worker:
  1. Loads all messages for the session.
  2. Estimates the total token count. If the count is below `@token_threshold`
     the session is too short to be worth summarising and the job exits early.
  3. Runs `Microcompact.run/2` to strip stale tool-result content before sending
     to the LLM (keeps costs low and context focused).
  4. Sends the compacted messages to the configured LLM provider.
  5. Upserts the result via `SessionSummaries.create_or_update_summary/1`.

  LLM errors are swallowed and `:ok` is returned so Oban does not retry
  excessively — the job will be re-enqueued at the next session checkpoint.
  """

  use Oban.Worker, queue: :memory, max_attempts: 2

  alias James.Compaction.Microcompact
  alias James.{LLMProvider, Sessions, SessionSummaries}

  # Minimum estimated token count before we bother summarising.
  @token_threshold 10_000

  @summary_prompt """
  You are a concise summarisation assistant. Given the conversation below,
  produce a 2-4 sentence summary of what has been accomplished so far in this
  session. Focus on outcomes and decisions, not process details. Return only
  the summary text with no preamble or additional commentary.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    messages = Sessions.list_messages(session_id)

    if messages == [] do
      :ok
    else
      total_tokens = estimate_total_tokens(messages)

      if total_tokens < @token_threshold do
        :ok
      else
        {:ok, compacted, _tokens_saved} = Microcompact.run(messages)
        summarise_and_store(session_id, compacted)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp estimate_total_tokens(messages) do
    Enum.reduce(messages, 0, fn msg, acc ->
      count = msg.token_count || estimate_from_content(msg.content)
      acc + count
    end)
  end

  defp estimate_from_content(content) when is_binary(content),
    do: div(String.length(content), 4)

  defp estimate_from_content(_), do: 0

  defp summarise_and_store(session_id, messages) do
    conversation =
      Enum.map_join(messages, "\n\n", fn msg ->
        "#{msg.role}: #{msg.content}"
      end)

    case LLMProvider.configured().send_message(
           [%{role: "user", content: conversation}],
           system: @summary_prompt,
           model: "claude-haiku-3-20240307",
           max_tokens: 512
         ) do
      {:ok, %{content: summary}} when is_binary(summary) and summary != "" ->
        SessionSummaries.create_or_update_summary(%{
          session_id: session_id,
          content: summary
        })

        :ok

      _ ->
        :ok
    end
  end
end
