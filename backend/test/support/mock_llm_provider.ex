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
  @calls_table :mock_llm_calls

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

  @doc "Remove all pending responses and recorded calls."
  def flush do
    ensure_table()
    :ets.delete_all_objects(@table)
    ensure_calls_table()
    :ets.delete_all_objects(@calls_table)
    :ok
  end

  @doc "Return the opts passed to the most recent stream_message/send_message call."
  def last_call_opts do
    ensure_calls_table()

    case :ets.last(@calls_table) do
      :"$end_of_table" ->
        nil

      key ->
        [{^key, opts}] = :ets.lookup(@calls_table, key)
        opts
    end
  end

  @doc "Return all recorded call opts in order."
  def all_call_opts do
    ensure_calls_table()
    @calls_table |> :ets.tab2list() |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))
  end

  @doc "Pop the next queued response, or return a default success."
  def pop_response do
    ensure_table()

    case :ets.first(@table) do
      :"$end_of_table" ->
        {:ok,
         %{
           content: "Mock response",
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "end_turn"
         }}

      key ->
        [{^key, response}] = :ets.lookup(@table, key)
        :ets.delete(@table, key)
        response
    end
  end

  @impl James.LLMProvider
  def stream_message(_messages, opts \\ []) do
    record_call(opts)
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
  def send_message(_messages, opts \\ []) do
    record_call(opts)
    pop_response()
  end

  defp record_call(opts) do
    ensure_calls_table()
    key = System.unique_integer([:monotonic])
    :ets.insert(@calls_table, {key, opts})
  end

  defp ensure_calls_table do
    if :ets.whereis(@calls_table) == :undefined do
      :ets.new(@calls_table, [:named_table, :public, :ordered_set])
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :ordered_set])
    end
  end
end
