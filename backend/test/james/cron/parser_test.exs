defmodule James.Cron.ParserTest do
  use ExUnit.Case, async: true

  alias James.Cron.Parser

  describe "parse/1" do
    test "accepts '*/5 * * * *' (every 5 minutes)" do
      assert :ok = Parser.parse("*/5 * * * *")
    end

    test "accepts '0 9 * * 1' (Monday 9am)" do
      assert :ok = Parser.parse("0 9 * * 1")
    end

    test "rejects 'invalid' string" do
      assert {:error, :invalid_cron} = Parser.parse("invalid")
    end

    test "rejects expression with too few fields" do
      assert {:error, :invalid_cron} = Parser.parse("0 9 * *")
    end

    test "rejects expression with out-of-range minute" do
      assert {:error, :invalid_cron} = Parser.parse("60 9 * * *")
    end

    test "accepts comma-separated values '0,30 9 * * *'" do
      assert :ok = Parser.parse("0,30 9 * * *")
    end

    test "accepts step syntax '0 */2 * * *'" do
      assert :ok = Parser.parse("0 */2 * * *")
    end
  end

  describe "next_fire_at/2" do
    test "computes next time for '*/5 * * * *' from start of a 5-minute boundary" do
      # 2026-04-01 10:00:00 UTC — next should be 10:05:00
      now = ~U[2026-04-01 10:00:00Z]
      assert {:ok, next} = Parser.next_fire_at("*/5 * * * *", now)
      assert next == ~U[2026-04-01 10:05:00Z]
    end

    test "computes next time for '*/5 * * * *' mid-interval" do
      # 2026-04-01 10:02:00 UTC — next should be 10:05:00
      now = ~U[2026-04-01 10:02:00Z]
      assert {:ok, next} = Parser.next_fire_at("*/5 * * * *", now)
      assert next == ~U[2026-04-01 10:05:00Z]
    end

    test "computes next time for '0 9 * * 1' (Monday 9am) from a Wednesday" do
      # 2026-04-01 is a Wednesday; next Monday is 2026-04-06
      now = ~U[2026-04-01 10:00:00Z]
      assert {:ok, next} = Parser.next_fire_at("0 9 * * 1", now)
      assert next == ~U[2026-04-06 09:00:00Z]
    end

    test "computes next fire from a given DateTime before the trigger time" do
      # '0 12 * * *' from 11:59 — next should be same day at 12:00
      now = ~U[2026-04-01 11:59:00Z]
      assert {:ok, next} = Parser.next_fire_at("0 12 * * *", now)
      assert next == ~U[2026-04-01 12:00:00Z]
    end
  end
end
