defmodule James.Workers.MemoryExtractionWorker do
  @moduledoc """
  Oban worker that extracts memories from a session turn.
  Runs after each assistant response to extract decisions, preferences,
  entities, and open questions into the memory store.
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  alias James.{Embeddings, Memories, Sessions}
  alias James.Providers.Anthropic

  @extraction_prompt """
  You are a memory extraction system. Analyze the conversation and extract
  key information worth remembering for future sessions.

  Extract the following types of information:
  - Decisions made by the user
  - Stated preferences or requirements
  - Named entities (projects, tools, technologies, people)
  - Open questions or unresolved items
  - Important context about the user's goals

  Return ONLY a JSON array of extracted memories. Each memory should be a
  short, self-contained statement. If there is nothing worth extracting,
  return an empty array [].

  Example output:
  ["User prefers TypeScript over JavaScript", "Working on a project called James the Butler"]
  """

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id, "user_id" => user_id}}) do
    # Get recent messages (last turn)
    messages = Sessions.list_messages(session_id)

    if length(messages) < 2 do
      :ok
    else
      # Take the last few messages for extraction
      recent = Enum.take(messages, -4)

      conversation =
        Enum.map_join(recent, "\n\n", fn m -> "#{m.role}: #{m.content}" end)

      extract_and_store(conversation, user_id, session_id)
    end
  end

  defp extract_and_store(conversation, user_id, session_id) do
    case extract_memories(conversation) do
      {:ok, extracted} -> Enum.each(extracted, &store_memory(&1, user_id, session_id))
      {:error, _reason} -> :ok
    end
  end

  defp store_memory(text, user_id, session_id) do
    case Embeddings.generate(text) do
      {:ok, embedding} ->
        Memories.create_memory(%{
          user_id: user_id,
          content: text,
          embedding: embedding,
          source_session_id: session_id
        })

      {:error, _} ->
        # Store without embedding if embedding fails
        Memories.create_memory(%{
          user_id: user_id,
          content: text,
          source_session_id: session_id
        })
    end
  end

  defp extract_memories(conversation) do
    messages = [%{role: "user", content: conversation}]

    case Anthropic.send_message(messages,
           system: @extraction_prompt,
           model: "claude-haiku-3-20240307",
           max_tokens: 1024
         ) do
      {:ok, %{content: content}} ->
        parse_json_array(content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_json_array(text) do
    # Try to find and parse a JSON array in the response
    case Jason.decode(String.trim(text)) do
      {:ok, list} when is_list(list) ->
        {:ok, Enum.filter(list, &is_binary/1)}

      _ ->
        # Try to extract array from surrounding text
        parse_json_array_from_text(text)
    end
  end

  defp parse_json_array_from_text(text) do
    case Regex.run(~r/\[.*\]/s, text) do
      [json] -> decode_json_list(json)
      nil -> {:ok, []}
    end
  end

  defp decode_json_list(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> {:ok, Enum.filter(list, &is_binary/1)}
      _ -> {:ok, []}
    end
  end
end
