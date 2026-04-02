defmodule James.TelemetryTest do
  @moduledoc """
  Unit tests for the James.Telemetry helper module.
  These tests verify the public API without requiring a live OTLP collector.
  The OpenTelemetry SDK operates in no-op mode when no exporter is configured.
  """

  use ExUnit.Case, async: true

  alias James.Telemetry

  describe "setup/0" do
    test "attaches Phoenix, Ecto and Oban instrumentation handlers without raising" do
      # OTel deps are installed; calling setup/0 should succeed regardless of
      # whether a collector is reachable (SDK silently drops spans when not configured).
      assert :ok = Telemetry.setup()
    end

    test "is safe to call multiple times (idempotent)" do
      assert :ok = Telemetry.setup()
      assert :ok = Telemetry.setup()
    end
  end

  describe "with_span/3" do
    test "executes the given function and returns its value" do
      result = Telemetry.with_span("test.span", %{key: "value"}, fn -> :ok end)
      assert result == :ok
    end

    test "propagates return value from the wrapped function" do
      result = Telemetry.with_span("test.span", %{}, fn -> {:ok, 42} end)
      assert result == {:ok, 42}
    end

    test "works with default (empty) attributes map" do
      assert :done = Telemetry.with_span("test.span", fn -> :done end)
    end

    test "propagates exceptions raised inside the span" do
      assert_raise RuntimeError, "boom", fn ->
        Telemetry.with_span("test.span", %{}, fn -> raise "boom" end)
      end
    end
  end

  describe "set_attributes/1" do
    test "returns :ok when called outside a span" do
      assert :ok = Telemetry.set_attributes(%{foo: "bar", baz: 1})
    end

    test "accepts a map with atom keys" do
      assert :ok = Telemetry.set_attributes(%{service: "james", env: "test"})
    end
  end

  describe "app_name/0" do
    test "returns :james" do
      assert Telemetry.app_name() == :james
    end
  end
end
