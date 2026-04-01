defmodule James.Compaction.Microcompact do
  @moduledoc """
  Pure-function module that strips stale tool result content from message history
  before LLM summarization.

  This module performs a "microcompact" pass over a list of messages, replacing
  old tool result content with a placeholder string. It operates entirely on
  plain maps — no database access, no GenServer, no side effects.

  ## Strategy

  Tool result messages (`role: "tool"`) with names in `@compactable_tool_names`
  are candidates for stripping. The module keeps the `@keep_recent` most recent
  results **per tool name** and clears the rest. A time-based override kicks in
  when the gap since the last assistant message exceeds
  `@time_based_threshold_minutes`: in that case all compactable tool results are
  cleared regardless of recency.

  ## Token estimation

  Saved tokens are estimated as `div(byte_size(content), 4)`, which is a rough
  approximation of the GPT/Claude tokeniser heuristic.
  """

  @cleared_placeholder "[Old tool result content cleared]"

  @compactable_tool_names ~w[
    file_read
    bash
    grep
    glob
    web_search
    web_fetch
    file_edit
    file_write
    desktop_screenshot
    browser_screenshot
  ]

  @keep_recent 5
  @time_based_threshold_minutes 60

  @doc """
  Strips stale tool result content from `messages`.

  Returns `{:ok, stripped_messages, tokens_saved}`.

  ## Options

    * `:keep_recent` — number of most-recent results per tool type to keep
      (default: #{@keep_recent})
    * `:now` — `DateTime` used as "current time" for the time-based check
      (default: `DateTime.utc_now/0`)
  """
  @spec run(list(map()), keyword()) :: {:ok, list(map()), non_neg_integer()}
  def run(messages, opts \\ [])

  def run([], _opts), do: {:ok, [], 0}

  def run(messages, opts) do
    keep_recent = Keyword.get(opts, :keep_recent, @keep_recent)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    if time_based_clear?(messages, now) do
      {stripped, tokens_saved} = strip_all(messages)
      {:ok, stripped, tokens_saved}
    else
      {stripped, tokens_saved} = strip_by_recency(messages, keep_recent)
      {:ok, stripped, tokens_saved}
    end
  end

  @doc """
  Clears all compactable tool result content from `messages`.

  Returns the updated message list. Unlike `run/2`, this function does not
  compute tokens saved; use it when you need a simple clear-all operation.
  """
  @spec strip_all_compactable(list(map())) :: list(map())
  def strip_all_compactable(messages) do
    {stripped, _tokens_saved} = strip_all(messages)
    stripped
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Determines whether the time-based clear mode should be triggered.
  # Returns true when the gap between `now` and the last assistant message
  # exceeds @time_based_threshold_minutes.
  defp time_based_clear?(messages, now) do
    last_assistant =
      messages
      |> Enum.filter(&(&1.role == "assistant"))
      |> List.last()

    case last_assistant do
      nil ->
        false

      msg ->
        diff_minutes = DateTime.diff(now, msg.inserted_at, :second) / 60
        diff_minutes > @time_based_threshold_minutes
    end
  end

  # Clears ALL compactable tool results, accumulating tokens saved.
  defp strip_all(messages) do
    Enum.map_reduce(messages, 0, fn msg, acc ->
      if compactable?(msg) do
        tokens = estimate_tokens(msg.content)
        {%{msg | content: @cleared_placeholder}, acc + tokens}
      else
        {msg, acc}
      end
    end)
  end

  # Strips tool results keeping only the `keep_recent` most recent per tool name.
  defp strip_by_recency(messages, keep_recent) do
    # Identify IDs to preserve: the keep_recent most recent per tool name.
    ids_to_keep = compute_ids_to_keep(messages, keep_recent)

    Enum.map_reduce(messages, 0, fn msg, acc ->
      if compactable?(msg) and msg.id not in ids_to_keep do
        tokens = estimate_tokens(msg.content)
        {%{msg | content: @cleared_placeholder}, acc + tokens}
      else
        {msg, acc}
      end
    end)
  end

  # Returns a MapSet of message IDs that should be preserved (most recent N per
  # tool name).
  defp compute_ids_to_keep(messages, keep_recent) do
    messages
    |> Enum.filter(&compactable?/1)
    |> Enum.group_by(& &1.name)
    |> Enum.flat_map(fn {_name, group} ->
      group
      |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
      |> Enum.take(-keep_recent)
      |> Enum.map(& &1.id)
    end)
    |> MapSet.new()
  end

  defp compactable?(%{role: "tool", name: name}) when name in @compactable_tool_names, do: true
  defp compactable?(_), do: false

  defp estimate_tokens(content) when is_binary(content), do: div(String.length(content), 4)
  defp estimate_tokens(_), do: 0
end
