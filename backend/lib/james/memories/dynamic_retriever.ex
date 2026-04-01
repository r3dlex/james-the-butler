defmodule James.Memories.DynamicRetriever do
  @moduledoc """
  Retrieves memories relevant to the current user message using LLM selection.

  Given a user message and a user ID, this module:
  1. Loads candidate memories for the user.
  2. Calls the LLM to select the most relevant memory IDs.
  3. Returns the corresponding memories, capped at `@max_results`.

  Accepts an optional `frozen_ids` list to exclude memories already included
  in the frozen snapshot from the returned results.
  """

  alias James.{LLMProvider, Memories}

  @max_results 5

  @doc """
  Returns memories relevant to `user_message` for `user_id`.

  ## Options

    * `:max_results` — maximum number of memories to return (default `#{@max_results}`).
    * `:frozen_ids` — list of memory IDs already in the frozen snapshot; these
      are excluded from the candidates passed to the LLM and from the results.
    * `:llm_provider` — override the LLM provider module (used in tests).
  """
  @spec find_relevant(String.t(), binary(), keyword()) :: [Memories.Memory.t()]
  def find_relevant(user_message, user_id, opts \\ []) do
    max = Keyword.get(opts, :max_results, @max_results)
    frozen_ids = Keyword.get(opts, :frozen_ids, [])
    provider = Keyword.get(opts, :llm_provider) || LLMProvider.configured()

    candidates =
      user_id
      |> Memories.list_memories(limit: 50)
      |> Enum.reject(fn m -> m.id in frozen_ids end)

    if candidates == [] do
      []
    else
      select_relevant(candidates, user_message, max, provider)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp select_relevant(candidates, user_message, max, provider) do
    candidate_list =
      candidates
      |> Enum.map(fn m -> %{id: m.id, content: m.content} end)
      |> Jason.encode!()

    messages = [
      %{
        role: "user",
        content: """
        You are a memory relevance filter. Given the user message and a list of
        candidate memories, return a JSON array of memory IDs that are relevant
        to the message. Return at most #{max} IDs. Respond ONLY with valid JSON —
        a plain JSON array of UUID strings, e.g. ["id1","id2"].

        User message: #{user_message}

        Candidates:
        #{candidate_list}
        """
      }
    ]

    case provider.send_message(messages, []) do
      {:ok, %{content: content}} ->
        decode_ids(content, candidates, max)

      {:error, _reason} ->
        []
    end
  end

  defp decode_ids(content, candidates, max) do
    candidate_map = Map.new(candidates, fn m -> {m.id, m} end)

    with {:ok, ids} <- Jason.decode(content),
         true <- is_list(ids) do
      ids
      |> Enum.take(max)
      |> Enum.flat_map(&lookup_candidate(&1, candidate_map))
    else
      _ -> []
    end
  end

  defp lookup_candidate(id, candidate_map) do
    case Map.fetch(candidate_map, id) do
      {:ok, mem} -> [mem]
      :error -> []
    end
  end
end
