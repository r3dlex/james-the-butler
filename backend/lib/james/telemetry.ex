defmodule James.Telemetry do
  @moduledoc """
  Instruments the application with OpenTelemetry.

  Called from `James.Application.start/2` before the supervision tree so that
  all subsequent telemetry events emitted by Phoenix, Ecto, and Oban are
  captured and forwarded to the configured OTLP exporter.

  ## Instrumented libraries

  - **Phoenix** — HTTP requests and LiveView events via `opentelemetry_phoenix`
  - **Ecto** — SQL queries via `opentelemetry_ecto`
  - **Oban** — background job spans via `opentelemetry_oban`

  ## Custom spans

  Use the helper macros exported from this module instead of calling the
  OpenTelemetry API directly, so the span attributes stay consistent:

      James.Telemetry.with_span("planner.decompose", %{session_id: id}, fn ->
        ...
      end)
  """

  require OpenTelemetry.Tracer, as: Tracer

  @app_name :james

  # ---------------------------------------------------------------------------
  # Setup — called once at application start
  # ---------------------------------------------------------------------------

  @doc """
  Attaches all instrumentation handlers. Safe to call multiple times (handlers
  are identified by a unique name and silently skip if already attached).
  """
  def setup do
    :ok = OpentelemetryPhoenix.setup()
    :ok = OpentelemetryEcto.setup([:james, :repo])
    :ok = OpentelemetryOban.setup()
  end

  # ---------------------------------------------------------------------------
  # Convenience helpers
  # ---------------------------------------------------------------------------

  @doc """
  Wraps `fun` in an OpenTelemetry span named `name` with the given `attrs`.

  ## Examples

      James.Telemetry.with_span("llm.request", %{provider: "anthropic"}, fn ->
        LLMProvider.send_message(messages, opts)
      end)
  """
  def with_span(name, attrs \\ %{}, fun) when is_binary(name) and is_function(fun, 0) do
    Tracer.with_span(name, %{attributes: stringify_keys(attrs)}) do
      fun.()
    end
  end

  @doc """
  Sets attributes on the current active span. Returns `:ok`.
  """
  def set_attributes(attrs) when is_map(attrs) do
    Tracer.set_attributes(stringify_keys(attrs))
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  @doc false
  def app_name, do: @app_name
end
