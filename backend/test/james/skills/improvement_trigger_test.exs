defmodule James.Skills.ImprovementTriggerTest do
  use James.DataCase

  alias James.Skills.ImprovementTrigger

  describe "triggered?/1" do
    test "returns false when tool_call_count is below 5" do
      context = %{tool_call_count: 4, retry_count: 0, failure_count: 0}
      refute ImprovementTrigger.triggered?(context)
    end

    test "returns true when tool_call_count reaches 5" do
      context = %{tool_call_count: 5, retry_count: 0, failure_count: 0}
      assert ImprovementTrigger.triggered?(context)
    end

    test "returns true when retry_count is 2 or more" do
      context = %{tool_call_count: 0, retry_count: 2, failure_count: 0}
      assert ImprovementTrigger.triggered?(context)
    end

    test "returns true when failure_count is 1 or more" do
      context = %{tool_call_count: 0, retry_count: 0, failure_count: 1}
      assert ImprovementTrigger.triggered?(context)
    end

    test "returns false when all counts are zero" do
      context = %{tool_call_count: 0, retry_count: 0, failure_count: 0}
      refute ImprovementTrigger.triggered?(context)
    end

    test "accepts missing keys as zero" do
      refute ImprovementTrigger.triggered?(%{})
    end
  end

  describe "score/1" do
    test "returns a numeric score reflecting urgency" do
      low = ImprovementTrigger.score(%{tool_call_count: 1, retry_count: 0, failure_count: 0})
      high = ImprovementTrigger.score(%{tool_call_count: 10, retry_count: 3, failure_count: 2})
      assert is_number(low)
      assert is_number(high)
      assert high > low
    end

    test "returns 0 for empty context" do
      assert ImprovementTrigger.score(%{}) == 0
    end
  end

  describe "reason/1" do
    test "returns :tool_calls when tool_call_count >= 5" do
      assert ImprovementTrigger.reason(%{tool_call_count: 5, retry_count: 0, failure_count: 0}) ==
               :tool_calls
    end

    test "returns :retries when retry_count >= 2 and tool_calls not dominant" do
      assert ImprovementTrigger.reason(%{tool_call_count: 0, retry_count: 2, failure_count: 0}) ==
               :retries
    end

    test "returns :failure when failure_count >= 1 and other counts low" do
      assert ImprovementTrigger.reason(%{tool_call_count: 0, retry_count: 0, failure_count: 1}) ==
               :failure
    end

    test "returns nil when not triggered" do
      assert ImprovementTrigger.reason(%{tool_call_count: 0, retry_count: 0, failure_count: 0}) ==
               nil
    end
  end
end
