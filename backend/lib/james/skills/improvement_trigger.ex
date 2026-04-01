defmodule James.Skills.ImprovementTrigger do
  @moduledoc """
  GEPA-style heuristic trigger for skill improvement.

  Evaluates a session execution context and decides whether the current skill
  should be evolved. Triggers fire when:
  - `tool_call_count >= 5` — excessive tool use signals a skill inefficiency
  - `retry_count >= 2`    — multiple retries indicate the skill is fragile
  - `failure_count >= 1`  — any failure flags the skill for review

  The `score/1` function returns a numeric urgency score for prioritisation.
  The `reason/1` function returns the dominant trigger reason atom.
  """

  @tool_call_threshold 5
  @retry_threshold 2
  @failure_threshold 1

  @doc """
  Returns `true` when any improvement heuristic fires for the given context.

  Context keys (all optional, default to 0):
  - `:tool_call_count` — number of tool calls in the session turn
  - `:retry_count`     — number of retries attempted
  - `:failure_count`   — number of failures encountered
  """
  @spec triggered?(map()) :: boolean()
  def triggered?(context) do
    tool_calls(context) >= @tool_call_threshold or
      retries(context) >= @retry_threshold or
      failures(context) >= @failure_threshold
  end

  @doc """
  Returns a numeric urgency score. Higher = more urgent evolution.
  Combines weighted contributions from each heuristic signal.
  """
  @spec score(map()) :: number()
  def score(context) do
    tool_calls(context) + retries(context) * 3 + failures(context) * 5
  end

  @doc """
  Returns the dominant trigger reason atom, or `nil` if not triggered.

  Precedence: `:tool_calls` > `:retries` > `:failure`
  """
  @spec reason(map()) :: :tool_calls | :retries | :failure | nil
  def reason(context) do
    cond do
      tool_calls(context) >= @tool_call_threshold -> :tool_calls
      retries(context) >= @retry_threshold -> :retries
      failures(context) >= @failure_threshold -> :failure
      true -> nil
    end
  end

  defp tool_calls(ctx), do: Map.get(ctx, :tool_call_count, 0)
  defp retries(ctx), do: Map.get(ctx, :retry_count, 0)
  defp failures(ctx), do: Map.get(ctx, :failure_count, 0)
end
