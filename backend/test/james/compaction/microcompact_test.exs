defmodule James.Compaction.MicrocompactTest do
  use ExUnit.Case, async: true

  alias James.Compaction.Microcompact

  # Helper to build a tool message map
  defp tool_msg(id, name, content, inserted_at) do
    %{id: id, role: "tool", name: name, content: content, inserted_at: inserted_at}
  end

  defp user_msg(id, content, inserted_at) do
    %{id: id, role: "user", content: content, inserted_at: inserted_at}
  end

  defp assistant_msg(id, content, inserted_at) do
    %{id: id, role: "assistant", content: content, inserted_at: inserted_at}
  end

  defp system_msg(id, content, inserted_at) do
    %{id: id, role: "system", content: content, inserted_at: inserted_at}
  end

  describe "run/1 with empty list" do
    test "returns {:ok, [], 0}" do
      assert {:ok, [], 0} = Microcompact.run([])
    end
  end

  describe "run/2 with no tool results" do
    test "passes messages through unchanged with tokens_saved = 0" do
      now = ~U[2026-04-01 12:00:00Z]

      messages = [
        user_msg("1", "Hello", now),
        assistant_msg("2", "Hi there!", now),
        system_msg("3", "System init", now)
      ]

      assert {:ok, result, 0} = Microcompact.run(messages)
      assert result == messages
    end
  end

  describe "run/2 tool result stripping" do
    test "strips tool results older than the most recent 5 per tool type" do
      base = ~U[2026-04-01 10:00:00Z]

      # 7 file_read results — first 2 should be stripped
      messages =
        Enum.map(1..7, fn i ->
          tool_msg(
            "#{i}",
            "file_read",
            "content #{i}",
            DateTime.add(base, i * 60, :second)
          )
        end)

      assert {:ok, result, tokens_saved} = Microcompact.run(messages)

      # First 2 should be stripped
      [m1, m2 | rest] = result
      assert m1.content == "[Old tool result content cleared]"
      assert m2.content == "[Old tool result content cleared]"

      # Last 5 should be preserved
      Enum.each(rest, fn m ->
        refute m.content == "[Old tool result content cleared]"
      end)

      assert tokens_saved > 0
    end

    test "preserves all tool results when count <= 5" do
      base = ~U[2026-04-01 10:00:00Z]

      messages =
        Enum.map(1..5, fn i ->
          tool_msg("#{i}", "bash", "output #{i}", DateTime.add(base, i * 60, :second))
        end)

      assert {:ok, result, 0} = Microcompact.run(messages)
      Enum.each(result, fn m -> refute m.content == "[Old tool result content cleared]" end)
    end

    test "strips correctly across multiple tool types independently" do
      base = ~U[2026-04-01 10:00:00Z]

      # 6 file_read + 6 bash — 1 each should be stripped
      file_reads =
        Enum.map(1..6, fn i ->
          tool_msg(
            "fr#{i}",
            "file_read",
            "file content #{i}",
            DateTime.add(base, i * 10, :second)
          )
        end)

      bashes =
        Enum.map(1..6, fn i ->
          tool_msg(
            "bash#{i}",
            "bash",
            "bash output #{i}",
            DateTime.add(base, i * 10 + 1, :second)
          )
        end)

      messages = Enum.sort_by(file_reads ++ bashes, & &1.inserted_at)

      assert {:ok, result, tokens_saved} = Microcompact.run(messages)

      stripped = Enum.filter(result, fn m -> m.content == "[Old tool result content cleared]" end)
      # 1 file_read + 1 bash stripped
      assert length(stripped) == 2
      assert tokens_saved > 0
    end
  end

  describe "run/2 non-tool-result messages are never modified" do
    test "user, assistant, and system messages pass through unchanged" do
      base = ~U[2026-04-01 10:00:00Z]

      messages = [
        system_msg("s1", "system setup", base),
        user_msg("u1", "user message with lots of text", DateTime.add(base, 10, :second)),
        assistant_msg("a1", "assistant reply", DateTime.add(base, 20, :second)),
        tool_msg("t1", "file_read", "some file content", DateTime.add(base, 30, :second))
      ]

      assert {:ok, result, _} = Microcompact.run(messages)

      system_result = Enum.find(result, &(&1.id == "s1"))
      user_result = Enum.find(result, &(&1.id == "u1"))
      assistant_result = Enum.find(result, &(&1.id == "a1"))

      assert system_result.content == "system setup"
      assert user_result.content == "user message with lots of text"
      assert assistant_result.content == "assistant reply"
    end
  end

  describe "run/2 time-based mode" do
    test "when gap since last assistant message > 60 min, ALL tool results are cleared" do
      old = ~U[2026-04-01 09:00:00Z]
      # last assistant message was 61 minutes ago
      last_assistant = ~U[2026-04-01 10:00:00Z]
      now = ~U[2026-04-01 11:01:00Z]

      messages = [
        assistant_msg("a1", "last assistant message", last_assistant),
        tool_msg("t1", "file_read", "content 1", DateTime.add(old, 10, :second)),
        tool_msg("t2", "bash", "output 2", DateTime.add(old, 20, :second)),
        tool_msg("t3", "grep", "result 3", DateTime.add(old, 30, :second))
      ]

      assert {:ok, result, tokens_saved} = Microcompact.run(messages, now: now)

      tool_results = Enum.filter(result, &(&1.role == "tool"))

      Enum.each(tool_results, fn m ->
        assert m.content == "[Old tool result content cleared]"
      end)

      assert tokens_saved > 0
    end

    test "within 60 min of last assistant message, normal keep_recent rules apply" do
      last_assistant = ~U[2026-04-01 10:00:00Z]
      # only 30 minutes ago
      now = ~U[2026-04-01 10:30:00Z]

      messages = [
        assistant_msg("a1", "assistant", last_assistant),
        tool_msg("t1", "file_read", "content 1", DateTime.add(last_assistant, 10, :second)),
        tool_msg("t2", "file_read", "content 2", DateTime.add(last_assistant, 20, :second))
      ]

      assert {:ok, result, 0} = Microcompact.run(messages, now: now)

      tool_results = Enum.filter(result, &(&1.role == "tool"))

      Enum.each(tool_results, fn m ->
        refute m.content == "[Old tool result content cleared]"
      end)
    end
  end

  describe "run/2 mixed content messages" do
    test "messages with both text and tool_result role — only tool_result role messages are cleared" do
      base = ~U[2026-04-01 10:00:00Z]

      # Build 6 tool messages to trigger stripping, first will be cleared
      messages =
        Enum.map(1..6, fn i ->
          tool_msg(
            "#{i}",
            "web_fetch",
            "fetched content #{i}",
            DateTime.add(base, i * 60, :second)
          )
        end)

      # Mix in a user message
      mixed = [user_msg("u1", "my query here", base) | messages]

      assert {:ok, result, tokens_saved} = Microcompact.run(mixed)

      user_result = Enum.find(result, &(&1.id == "u1"))
      assert user_result.content == "my query here"
      assert tokens_saved > 0
    end
  end

  describe "strip_all_compactable/1" do
    test "clears all compactable tool results" do
      base = ~U[2026-04-01 10:00:00Z]

      messages = [
        user_msg("u1", "hello", base),
        tool_msg("t1", "file_read", "content", DateTime.add(base, 10, :second)),
        tool_msg("t2", "bash", "output", DateTime.add(base, 20, :second)),
        tool_msg("t3", "web_search", "results", DateTime.add(base, 30, :second)),
        assistant_msg("a1", "done", DateTime.add(base, 40, :second))
      ]

      result = Microcompact.strip_all_compactable(messages)

      assert Enum.find(result, &(&1.id == "u1")).content == "hello"
      assert Enum.find(result, &(&1.id == "a1")).content == "done"

      tool_results = Enum.filter(result, &(&1.role == "tool"))

      Enum.each(tool_results, fn m ->
        assert m.content == "[Old tool result content cleared]"
      end)
    end

    test "non-compactable tool names are preserved" do
      base = ~U[2026-04-01 10:00:00Z]

      # A tool not in the compactable list
      messages = [
        %{id: "t1", role: "tool", name: "custom_tool", content: "keep me", inserted_at: base}
      ]

      result = Microcompact.strip_all_compactable(messages)
      assert hd(result).content == "keep me"
    end
  end

  describe "run/2 custom keep_recent option" do
    test "keep_recent: 2 keeps only the 2 most recent tool results per type" do
      base = ~U[2026-04-01 10:00:00Z]

      # 4 file_read messages — first 2 should be stripped with keep_recent: 2
      messages =
        Enum.map(1..4, fn i ->
          tool_msg("#{i}", "file_read", "content #{i}", DateTime.add(base, i * 60, :second))
        end)

      assert {:ok, result, tokens_saved} = Microcompact.run(messages, keep_recent: 2)

      [m1, m2 | rest] = result
      assert m1.content == "[Old tool result content cleared]"
      assert m2.content == "[Old tool result content cleared]"

      Enum.each(rest, fn m ->
        refute m.content == "[Old tool result content cleared]"
      end)

      assert tokens_saved > 0
    end
  end

  describe "token estimation" do
    test "tokens_saved is estimated as div(content_length, 4)" do
      base = ~U[2026-04-01 10:00:00Z]

      # 6 messages to trigger stripping of 1, content is 40 chars
      content = String.duplicate("x", 40)

      messages =
        Enum.map(1..6, fn i ->
          tool_msg("#{i}", "file_read", content, DateTime.add(base, i * 60, :second))
        end)

      assert {:ok, _result, tokens_saved} = Microcompact.run(messages)
      # 1 message stripped, 40 chars / 4 = 10 tokens
      assert tokens_saved == 10
    end
  end
end
