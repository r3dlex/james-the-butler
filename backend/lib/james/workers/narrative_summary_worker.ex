defmodule James.Workers.NarrativeSummaryWorker do
  @moduledoc """
  Oban worker that generates a human-readable narrative summary for a session
  and stores it in the execution_history table.
  Enqueued after each session checkpoint to keep summaries fresh.
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  alias James.{ExecutionHistory, LLMProvider, Sessions}

  @summary_prompt """
  You are a summarization assistant. Given the conversation below, write a concise
  1-3 sentence narrative summary describing what was accomplished. Focus on outcomes,
  not process. Be specific about any decisions made, code written, or files changed.
  Return only the summary text with no preamble.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    messages = Sessions.list_messages(session_id)

    if length(messages) < 2 do
      :ok
    else
      conversation =
        messages
        |> Enum.take(-20)
        |> Enum.map_join("\n\n", fn m -> "#{m.role}: #{m.content}" end)

      generate_and_store(session_id, conversation)
    end
  end

  defp generate_and_store(session_id, conversation) do
    case LLMProvider.configured().send_message(
           [%{role: "user", content: conversation}],
           system: @summary_prompt,
           model: "claude-haiku-3-20240307",
           max_tokens: 256
         ) do
      {:ok, %{content: narrative}} ->
        ExecutionHistory.create_entry(%{
          session_id: session_id,
          narrative_summary: narrative,
          structured_log: %{source: "narrative_summary_worker"}
        })

        :ok

      {:error, _reason} ->
        :ok
    end
  end
end
