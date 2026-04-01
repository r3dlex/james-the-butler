defmodule James.LLMProviderTest do
  use ExUnit.Case, async: true

  alias James.LLMProvider
  alias James.Test.MockLLMProvider

  describe "configured/0" do
    test "returns the configured provider module" do
      # In test env this is MockLLMProvider (set in config/test.exs)
      assert LLMProvider.configured() == MockLLMProvider
    end

    test "configured module implements stream_message/2" do
      provider = LLMProvider.configured()
      assert function_exported?(provider, :stream_message, 2)
    end

    test "configured module implements send_message/2" do
      provider = LLMProvider.configured()
      assert function_exported?(provider, :send_message, 2)
    end
  end

  describe "MockLLMProvider" do
    setup do
      MockLLMProvider.flush()
      :ok
    end

    test "returns default success response when queue is empty" do
      assert {:ok, result} = MockLLMProvider.stream_message([%{role: "user", content: "hi"}])
      assert is_binary(result.content) or is_list(result.content)
    end

    test "returns pushed response in FIFO order" do
      MockLLMProvider.push_response(
        {:ok, %{content: "first", usage: %{}, stop_reason: "end_turn"}}
      )

      MockLLMProvider.push_response(
        {:ok, %{content: "second", usage: %{}, stop_reason: "end_turn"}}
      )

      {:ok, r1} = MockLLMProvider.stream_message([])
      {:ok, r2} = MockLLMProvider.stream_message([])

      assert r1.content == "first"
      assert r2.content == "second"
    end

    test "returns error response when error is pushed" do
      MockLLMProvider.push_response({:error, "mocked error"})
      assert {:error, "mocked error"} = MockLLMProvider.stream_message([])
    end

    test "flush clears all queued responses" do
      MockLLMProvider.push_response(
        {:ok, %{content: "queued", usage: %{}, stop_reason: "end_turn"}}
      )

      MockLLMProvider.flush()
      # Should return default now
      assert {:ok, result} = MockLLMProvider.stream_message([])
      assert result.content == "Mock response"
    end

    test "send_message returns pushed response" do
      MockLLMProvider.push_response({:ok, %{content: "send result", usage: %{}}})
      assert {:ok, %{content: "send result"}} = MockLLMProvider.send_message([])
    end
  end
end
