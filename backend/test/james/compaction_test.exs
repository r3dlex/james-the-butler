defmodule James.CompactionTest do
  use James.DataCase

  alias James.{Accounts, Compaction, Sessions}

  defp create_user(email \\ "compact_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session_with_messages(user, message_count, token_per_msg \\ 100) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Compact Session"})

    Enum.each(1..message_count, fn i ->
      Sessions.create_message(%{
        session_id: session.id,
        role: if(rem(i, 2) == 0, do: "assistant", else: "user"),
        content: "Message #{i} content",
        token_count: token_per_msg
      })
    end)

    session
  end

  describe "token_ratio/2" do
    test "returns ratio of total message tokens to context_limit" do
      user = create_user()
      session = create_session_with_messages(user, 4, 200)
      # 4 * 200 = 800 tokens; context_limit default 10_000 → 0.08
      ratio = Compaction.token_ratio(session.id, context_limit: 10_000)
      assert_in_delta ratio, 0.08, 0.001
    end

    test "returns 0.0 for session with no messages" do
      user = create_user("empty_session@example.com")
      {:ok, session} = Sessions.create_session(%{user_id: user.id})
      assert Compaction.token_ratio(session.id) == 0.0
    end

    test "returns 1.0 when tokens exceed context_limit" do
      user = create_user("overflow@example.com")
      session = create_session_with_messages(user, 5, 2_100)
      # 5 * 2100 = 10_500 tokens; ratio capped at 1.0
      ratio = Compaction.token_ratio(session.id, context_limit: 10_000)
      assert ratio == 1.0
    end
  end

  describe "needs_compaction?/2" do
    test "returns false when token ratio is below 0.8 threshold" do
      user = create_user("below_threshold@example.com")
      session = create_session_with_messages(user, 2, 100)
      refute Compaction.needs_compaction?(session.id, context_limit: 10_000)
    end

    test "returns true when token ratio meets 0.8 threshold" do
      user = create_user("above_threshold@example.com")
      # 40 msgs * 201 tokens = 8040 / 10_000 = 0.804 → needs compaction
      session = create_session_with_messages(user, 40, 201)
      assert Compaction.needs_compaction?(session.id, context_limit: 10_000)
    end
  end

  describe "compact!/3" do
    test "creates a checkpoint containing the summary" do
      user = create_user("compact_checkpoint@example.com")
      session = create_session_with_messages(user, 6, 100)
      summary = "This session discussed project setup."

      assert {:ok, checkpoint} = Compaction.compact!(session.id, summary)

      assert checkpoint.session_id == session.id
      assert checkpoint.metadata["summary"] == summary
    end

    test "stores message count in checkpoint metadata" do
      user = create_user("compact_count@example.com")
      session = create_session_with_messages(user, 6, 100)
      {:ok, checkpoint} = Compaction.compact!(session.id, "Summary")

      # All 6 messages were compacted (with default keep_last: 4, 2 would remain)
      assert checkpoint.metadata["message_count"] >= 1
    end

    test "preserves the most recent messages after compaction" do
      user = create_user("compact_preserve@example.com")
      session = create_session_with_messages(user, 6, 100)
      {:ok, _checkpoint} = Compaction.compact!(session.id, "Summary", keep_last: 2)

      active_messages = Sessions.list_messages(session.id)
      assert length(active_messages) == 2
    end

    test "deletes compacted messages leaving only keep_last messages" do
      user = create_user("compact_delete@example.com")
      session = create_session_with_messages(user, 8, 100)

      {:ok, _checkpoint} = Compaction.compact!(session.id, "Summary", keep_last: 3)

      remaining = Sessions.list_messages(session.id)
      assert length(remaining) == 3
    end

    test "stores compacted messages in checkpoint conversation_snapshot" do
      user = create_user("compact_snapshot@example.com")
      session = create_session_with_messages(user, 6, 100)

      {:ok, checkpoint} = Compaction.compact!(session.id, "Summary", keep_last: 2)

      snapshot = checkpoint.conversation_snapshot
      assert is_list(snapshot["messages"])
      # 6 total - 2 kept = 4 compacted
      assert length(snapshot["messages"]) == 4
    end
  end

  describe "summarize_messages/2" do
    test "returns a non-empty binary summary" do
      messages = [
        %{role: "user", content: "What is the capital of France?"},
        %{role: "assistant", content: "The capital of France is Paris."}
      ]

      result = Compaction.summarize_messages(messages, mode: :mock)
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "mock mode returns deterministic summary" do
      messages = [%{role: "user", content: "Hello"}]
      result = Compaction.summarize_messages(messages, mode: :mock)
      assert result =~ "[mock summary:"
    end
  end

  describe "fork_session/2" do
    test "creates a new session derived from the compacted one" do
      user = create_user("fork_session@example.com")
      session = create_session_with_messages(user, 4, 100)
      {:ok, checkpoint} = Compaction.compact!(session.id, "Forked session summary.")

      {:ok, forked} = Compaction.fork_session(session.id, checkpoint.id)

      assert forked.id != session.id
      assert forked.user_id == session.user_id
    end

    test "forked session has a system message with the checkpoint summary" do
      user = create_user("fork_summary@example.com")
      session = create_session_with_messages(user, 4, 100)
      summary = "Important context from previous session."
      {:ok, checkpoint} = Compaction.compact!(session.id, summary)

      {:ok, forked} = Compaction.fork_session(session.id, checkpoint.id)

      messages = Sessions.list_messages(forked.id)
      assert Enum.any?(messages, fn m ->
               m.role == "system" and String.contains?(m.content, summary)
             end)
    end

    test "forked session name references the original session" do
      user = create_user("fork_name@example.com")
      session = create_session_with_messages(user, 4, 100)
      {:ok, checkpoint} = Compaction.compact!(session.id, "Summary.")

      {:ok, forked} = Compaction.fork_session(session.id, checkpoint.id)

      assert String.contains?(forked.name || "", "fork") or
               String.contains?(forked.name || "", session.id)
    end
  end
end
