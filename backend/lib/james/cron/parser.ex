defmodule James.Cron.Parser do
  @moduledoc """
  Parses and evaluates 5-field cron expressions (minute hour day-of-month month day-of-week).

  Supports:
  - `*` — any value
  - `*/N` — every N steps
  - Specific integers
  - Comma-separated lists (e.g. `0,30`)
  """

  @field_ranges %{
    minute: 0..59,
    hour: 0..23,
    dom: 1..31,
    month: 1..12,
    dow: 0..6
  }

  @field_order [:minute, :hour, :dom, :month, :dow]

  @doc """
  Validates a 5-field cron expression.
  Returns `:ok` or `{:error, :invalid_cron}`.
  """
  @spec parse(String.t()) :: :ok | {:error, :invalid_cron}
  def parse(expr) when is_binary(expr) do
    parts = String.split(expr, " ", trim: true)

    if length(parts) == 5 do
      fields = Enum.zip(@field_order, parts)

      valid? =
        Enum.all?(fields, fn {field, token} ->
          range = @field_ranges[field]
          valid_token?(token, range)
        end)

      if valid?, do: :ok, else: {:error, :invalid_cron}
    else
      {:error, :invalid_cron}
    end
  end

  def parse(_), do: {:error, :invalid_cron}

  @doc """
  Computes the next fire DateTime after `now` for the given cron expression.

  Returns `{:ok, datetime}` or `{:error, :invalid_cron}`.
  The result is always rounded to whole minutes (seconds = 0).
  """
  @spec next_fire_at(String.t(), DateTime.t()) :: {:ok, DateTime.t()} | {:error, :invalid_cron}
  def next_fire_at(expr, %DateTime{} = now) do
    with :ok <- parse(expr),
         [min_tok, hour_tok, dom_tok, month_tok, dow_tok] <- String.split(expr, " ", trim: true) do
      # Advance by 1 minute from now (next fire is always in the future)
      start = advance_minute(now)
      result = find_next(start, min_tok, hour_tok, dom_tok, month_tok, dow_tok, 0)
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Private helpers ---

  defp advance_minute(%DateTime{} = dt) do
    dt
    |> DateTime.add(60, :second)
    |> truncate_to_minute()
  end

  defp truncate_to_minute(%DateTime{} = dt) do
    %{dt | second: 0, microsecond: {0, 0}}
  end

  # Iterates minute-by-minute (capped to avoid infinite loops)
  defp find_next(_dt, _min, _hour, _dom, _month, _dow, limit) when limit > 527_040 do
    # 527040 = minutes in a year; safety guard
    raise "Cron next_fire_at exceeded search limit"
  end

  defp find_next(dt, min_tok, hour_tok, dom_tok, month_tok, dow_tok, limit) do
    minute = dt.minute
    hour = dt.hour
    day = dt.day
    month = dt.month
    # Erlang weekday: Monday=1..Sunday=7; cron: Sunday=0..Saturday=6
    dow = day_of_week_cron(dt)

    min_range = @field_ranges.minute
    hour_range = @field_ranges.hour
    dom_range = @field_ranges.dom
    month_range = @field_ranges.month
    dow_range = @field_ranges.dow

    if matches?(minute, min_tok, min_range) and
         matches?(hour, hour_tok, hour_range) and
         matches?(day, dom_tok, dom_range) and
         matches?(month, month_tok, month_range) and
         matches?(dow, dow_tok, dow_range) do
      dt
    else
      next_dt = DateTime.add(dt, 60, :second)
      find_next(next_dt, min_tok, hour_tok, dom_tok, month_tok, dow_tok, limit + 1)
    end
  end

  # Returns cron-style day-of-week (0=Sunday..6=Saturday)
  defp day_of_week_cron(%DateTime{} = dt) do
    # Calendar.ISO.day_of_week/4 returns {day_of_week, min_day, max_day}
    # where day_of_week is 1=Monday..7=Sunday (ISO 8601)
    {iso_dow, _min, _max} = Calendar.ISO.day_of_week(dt.year, dt.month, dt.day, :monday)
    # Convert: ISO Monday=1 → cron Monday=1; ISO Sunday=7 → cron Sunday=0
    rem(iso_dow, 7)
  end

  defp matches?(_value, "*", _range), do: true

  defp matches?(value, "*/" <> step_str, range) do
    case Integer.parse(step_str) do
      {step, ""} when step > 0 ->
        Enum.member?(Enum.take_every(range, step), value)

      _ ->
        false
    end
  end

  defp matches?(value, token, range) do
    values =
      token
      |> String.split(",")
      |> Enum.map(&Integer.parse/1)

    if Enum.all?(values, fn
         {n, ""} -> n in range
         _ -> false
       end) do
      ints = Enum.map(values, fn {n, ""} -> n end)
      value in ints
    else
      false
    end
  end

  defp valid_token?("*", _range), do: true

  defp valid_token?("*/" <> step_str, range) do
    case Integer.parse(step_str) do
      {step, ""} when step > 0 -> step <= Enum.count(range)
      _ -> false
    end
  end

  defp valid_token?(token, range) do
    token
    |> String.split(",")
    |> Enum.all?(fn part ->
      case Integer.parse(part) do
        {n, ""} -> n in range
        _ -> false
      end
    end)
  end
end
