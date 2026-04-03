defmodule James.Workers.MemoryExtractionWorker do
  @moduledoc """
  Oban worker that extracts memories from a session turn.
  Runs after each assistant response to extract decisions, preferences,
  entities, and open questions into the memory store.

  Supports delta extraction via `last_extracted_message_id` argument:
  when provided, only messages after that ID are processed.

  Duplicate detection is performed before inserting: if a memory with
  the exact same content already exists for the user, it is skipped.
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  import Ecto.Query

  alias James.{Embeddings, LLMProvider, Memories, Repo, Sessions}
  alias James.Memories.Memory

  @extraction_prompt """
  You are a memory extraction system. Analyze the conversation and extract
  key information worth remembering for future sessions.

  Extract the following types of information:
  - Decisions made by the user
  - Stated preferences or requirements
  - Named entities (projects, tools, technologies, people)
  - Open questions or unresolved items
  - Important context about the user's goals
  - Codebase facts and navigation hints

  Return ONLY a JSON array of extracted memories. Each memory should be an
  object with "type" and "content" fields. Valid types are:
  - "codebase_fact" or "codebase_navigation" for code/context related memories
  - "user_preference" for stated preferences or requirements
  - "session_summary" for key decisions or outcomes
  - "general" for everything else

  If there is nothing worth extracting, return an empty array [].

  Example output:
  [{"type": "user_preference", "content": "User prefers TypeScript over JavaScript"}, {"type": "codebase_fact", "content": "Working on a project called James the Butler"}]
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"session_id" => session_id, "user_id" => user_id} = args
      }) do
    last_extracted_message_id = Map.get(args, "last_extracted_message_id")

    messages =
      case last_extracted_message_id do
        nil ->
          Sessions.list_messages(session_id)

        msg_id ->
          Sessions.list_messages_after(session_id, msg_id)
      end

    if length(messages) < 2 do
      :ok
    else
      recent = Enum.take(messages, -4)

      conversation =
        Enum.map_join(recent, "\n\n", fn m -> "#{m.role}: #{m.content}" end)

      extract_and_store(conversation, user_id, session_id)
    end
  end

  defp extract_and_store(conversation, user_id, session_id) do
    case extract_memories(conversation) do
      {:ok, extracted} ->
        extracted
        |> Enum.reject(&duplicate?(&1, user_id))
        |> Enum.each(&store_memory(&1, user_id, session_id))

      {:error, _reason} ->
        :ok
    end
  end

  defp duplicate?(%{content: content}, user_id) do
    Repo.exists?(
      from m in Memory,
        where: m.user_id == ^user_id and m.content == ^content
    )
  end

  defp duplicate?(_other, _user_id), do: false

  defp store_memory(%{type: type, content: content}, user_id, session_id) do
    memory_type = valid_memory_type(type)

    attrs = %{
      user_id: user_id,
      content: content,
      source_session_id: session_id,
      memory_type: memory_type
    }

    case Embeddings.generate(content) do
      {:ok, embedding} ->
        Memories.create_memory(Map.put(attrs, :embedding, embedding))

      {:error, _} ->
        Memories.create_memory(attrs)
    end
  end

  # Backward compatible: handle string memories (legacy format)
  defp store_memory(text, user_id, session_id) when is_binary(text) do
    attrs = %{
      user_id: user_id,
      content: text,
      source_session_id: session_id,
      memory_type: "general"
    }

    case Embeddings.generate(text) do
      {:ok, embedding} ->
        Memories.create_memory(Map.put(attrs, :embedding, embedding))

      {:error, _} ->
        Memories.create_memory(attrs)
    end
  end

  defp valid_memory_type(type)
       when type in ~w(general codebase_fact user_preference session_summary codebase_navigation),
       do: type

  defp valid_memory_type(_), do: "general"

  defp extract_memories(conversation) do
    messages = [%{role: "user", content: conversation}]

    case LLMProvider.configured().send_message(messages,
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
        {:ok, normalize_memories(list)}

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
      {:ok, list} when is_list(list) -> {:ok, normalize_memories(list)}
      _ -> {:ok, []}
    end
  end

  # Normalize to a consistent %{type: ..., content: ...} format
  # Handles both new map format and legacy string format
  defp normalize_memories(list) do
    list
    |> Enum.map(&normalize_single/1)
    |> Enum.filter(& &1)
  end

  defp normalize_single(%{"type" => type, "content" => content}) when is_binary(content) do
    %{type: type, content: content}
  end

  defp normalize_single(%{"type" => _, "content" => _}) do
    # content is not a string, skip
    nil
  end

  defp normalize_single(%{"type" => type}) when is_binary(type) do
    # Old format with just type, treat as general
    %{type: "general", content: type}
  end

  # Backward compatible: plain string
  defp normalize_single(binary) when is_binary(binary) do
    %{type: "general", content: binary}
  end

  defp normalize_single(_), do: nil
end
