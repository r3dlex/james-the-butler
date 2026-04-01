defmodule JamesCli.Formatter do
  @moduledoc """
  Formats CLI output in JSON, newline-delimited JSON (stream_json), or text.
  """

  @doc """
  Formats `data` according to `format`.

  - `:json`        — pretty-printed JSON
  - `:stream_json` — newline-delimited JSON (one JSON object per line)
  - `:text`        — human-readable text
  """
  @spec format(any(), :json | :stream_json | :text) :: String.t()
  def format(data, :json) do
    Jason.encode!(data, pretty: true)
  end

  def format(data, :stream_json) when is_list(data) do
    data
    |> Enum.map_join("\n", &Jason.encode!/1)
  end

  def format(data, :stream_json) do
    Jason.encode!(data)
  end

  def format(data, :text) when is_binary(data), do: data

  def format(data, :text) when is_map(data) do
    data
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map_join("\n", fn {k, v} -> "#{k}: #{format_value(v)}" end)
  end

  def format(data, :text) when is_list(data) do
    Enum.map_join(data, "\n", &format(&1, :text))
  end

  def format(data, :text) do
    inspect(data)
  end

  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_map(v) or is_list(v), do: Jason.encode!(v)
  defp format_value(v), do: inspect(v)
end
