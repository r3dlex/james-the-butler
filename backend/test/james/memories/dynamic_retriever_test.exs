defmodule James.Memories.DynamicRetrieverTest do
  use James.DataCase

  alias James.{Accounts, Memories}
  alias James.Memories.DynamicRetriever
  alias James.Test.MockLLMProvider

  defp create_user(email) do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_memory(user, content) do
    {:ok, memory} = Memories.create_memory(%{user_id: user.id, content: content})
    memory
  end

  setup do
    MockLLMProvider.flush()
    :ok
  end

  describe "find_relevant/3" do
    test "returns empty list when no memories exist" do
      user = create_user("dr_empty@example.com")
      result = DynamicRetriever.find_relevant("hello", user.id, llm_provider: MockLLMProvider)
      assert result == []
    end

    test "returns relevant memories based on LLM selection" do
      user = create_user("dr_relevant@example.com")
      m1 = create_memory(user, "I like Elixir")
      _m2 = create_memory(user, "I prefer Python")
      m3 = create_memory(user, "Phoenix is great")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: Jason.encode!([m1.id, m3.id]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      result =
        DynamicRetriever.find_relevant("Tell me about Elixir", user.id,
          llm_provider: MockLLMProvider
        )

      ids = Enum.map(result, & &1.id)
      assert m1.id in ids
      assert m3.id in ids
      refute Enum.any?(result, fn m -> m.content =~ "Python" end)
    end

    test "respects max_results limit" do
      user = create_user("dr_limit@example.com")
      memories = for i <- 1..6, do: create_memory(user, "Memory #{i}")
      all_ids = Enum.map(memories, & &1.id)

      MockLLMProvider.push_response(
        {:ok, %{content: Jason.encode!(all_ids), usage: %{input_tokens: 10, output_tokens: 5}}}
      )

      result =
        DynamicRetriever.find_relevant("test", user.id,
          max_results: 3,
          llm_provider: MockLLMProvider
        )

      assert length(result) == 3
    end

    test "handles LLM error gracefully (returns empty list)" do
      user = create_user("dr_error@example.com")
      _m = create_memory(user, "Some memory")

      MockLLMProvider.push_response({:error, "LLM unavailable"})

      result =
        DynamicRetriever.find_relevant("something", user.id, llm_provider: MockLLMProvider)

      assert result == []
    end

    test "excludes memories already in frozen snapshot" do
      user = create_user("dr_frozen@example.com")
      frozen = create_memory(user, "Frozen memory")
      live = create_memory(user, "Live memory")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: Jason.encode!([live.id]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      result =
        DynamicRetriever.find_relevant("something", user.id,
          frozen_ids: [frozen.id],
          llm_provider: MockLLMProvider
        )

      ids = Enum.map(result, & &1.id)
      refute frozen.id in ids
      assert live.id in ids
    end

    test "returns empty list when all candidates are in frozen snapshot" do
      user = create_user("dr_all_frozen@example.com")
      m1 = create_memory(user, "First memory")
      m2 = create_memory(user, "Second memory")

      result =
        DynamicRetriever.find_relevant("something", user.id,
          frozen_ids: [m1.id, m2.id],
          llm_provider: MockLLMProvider
        )

      assert result == []
    end
  end
end
