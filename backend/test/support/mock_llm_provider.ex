defmodule James.Test.MockLLMProvider do
  @moduledoc """
  Mock LLM provider for tests. Implements the `James.LLMProvider` behaviour.

  Uses an ETS FIFO queue so each test can pre-load responses and verify they
  are consumed in order. Falls back to a default success response when the
  queue is empty.

  Usage:

      # Pre-load a response for the next call
      MockLLMProvider.push_response({:ok, %{content: "Hello", usage: %{}, stop_reason: "end_turn"}})

      # Or push an error
      MockLLMProvider.push_response({:error, "API key not configured"})

      # After the test, optionally drain any remaining responses
      MockLLMProvider.flush()
  """

  @behaviour James.LLMProvider

  @table :mock_llm_responses

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker
    }
  end

  def start_link do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :ordered_set])
    end

    :ignore
  end

  @doc "Push a response onto the queue. Called in test setup."
  def push_response(response) do
    ensure_table()
    key = System.unique_integer([:monotonic])
    :ets.insert(@table, {key, response})
    :ok
  end

  @doc "Remove all pending responses."
  def flush do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Pop the next queued response, or return a default success."
  def pop_response do
    ensure_table()

    case :ets.first(@table) do
      :"$end_of_table" ->
        {:ok, %{content: "Mock response", usage: %{input_tokens: 10, output_tokens: 5}, stop_reason: "end_turn"}}

      key ->
        [{^key, response}] = :ets.lookup(@table, key)
        :ets.delete(@table, key)
        response
    end
  end

  @impl James.LLMProvider
  def stream_message(_messages, opts \\ []) do
    on_chunk = Keyword.get(opts, :on_chunk, fn _ -> :ok end)
    response = pop_response()

    case response do
      {:ok, %{content: content} = result} when is_binary(content) ->
        on_chunk.(content)
        {:ok, Map.put_new(result, :stop_reason, "end_turn")}

      {:ok, result} ->
        {:ok, Map.put_new(result, :stop_reason, "end_turn")}

      {:error, _} = err ->
        err
    end
  end

  @impl James.LLMProvider
  def send_message(_messages, _opts \\ []) do
    pop_response()
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :ordered_set])
    end
  end
end
