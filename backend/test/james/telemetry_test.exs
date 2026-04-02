defmodule James.TelemetryTest do
  @moduledoc """
  Unit tests for the James.Telemetry helper module.
  These tests verify the public API without requiring a live OTLP collector.
  """

  use ExUnit.Case, async: true

  alias James.Telemetry

  describe "with_span/3" do
    test "executes the given function and returns its value" do
      result = Telemetry.with_span("test.span", %{key: "value"}, fn -> :ok end)
      assert result == :ok
    end

    test "propagates return value from the wrapped function" do
      result = Telemetry.with_span("test.span", %{}, fn -> {:ok, 42} end)
      assert result == {:ok, 42}
    end

    test "works with an empty attributes map" do
      assert :done = Telemetry.with_span("test.span", fn -> :done end)
    end

    test "propagates exceptions raised inside the span" do
      assert_raise RuntimeError, "boom", fn ->
        Telemetry.with_span("test.span", %{}, fn -> raise "boom" end)
      end
    end
  end

  describe "set_attributes/1" do
    test "does not raise when called outside a span" do
      # Outside a span the SDK is a no-op; this should not crash.
      assert :ok = Telemetry.set_attributes(%{foo: "bar", baz: 1})
    end
  end

  describe "app_name/0" do
    test "returns :james" do
      assert Telemetry.app_name() == :james
    end
  end
end
