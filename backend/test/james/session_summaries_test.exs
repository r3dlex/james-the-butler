defmodule James.SessionSummariesTest do
  use James.DataCase

  alias James.{Accounts, Sessions, SessionSummaries}

  defp create_user(email \\ "summary_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Summary Session"})
    session
  end

  defp create_message(session) do
    {:ok, message} =
      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "Hello"
      })

    message
  end

  describe "create_or_update_summary/1" do
    test "creates a new summary for a session" do
      user = create_user()
      session = create_session(user)

      assert {:ok, summary} =
               SessionSummaries.create_or_update_summary(%{
                 session_id: session.id,
                 content: "Session so far: user asked about Elixir."
               })

      assert summary.session_id == session.id
      assert summary.content == "Session so far: user asked about Elixir."
    end

    test "updates existing summary (upsert on session_id)" do
      user = create_user("upsert_summary@example.com")
      session = create_session(user)

      {:ok, _first} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Initial summary."
        })

      {:ok, second} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Updated summary with more context."
        })

      assert second.content == "Updated summary with more context."

      assert SessionSummaries.get_summary(session.id).content ==
               "Updated summary with more context."
    end
  end

  describe "get_summary/1" do
    test "returns the summary for a session" do
      user = create_user("get_summary@example.com")
      session = create_session(user)

      {:ok, _} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "My summary."
        })

      summary = SessionSummaries.get_summary(session.id)
      assert summary.session_id == session.id
      assert summary.content == "My summary."
    end

    test "returns nil for session without summary" do
      user = create_user("no_summary@example.com")
      session = create_session(user)

      assert is_nil(SessionSummaries.get_summary(session.id))
    end
  end

  describe "get_fresh_summary/2" do
    test "returns summary if updated within max_age_minutes" do
      user = create_user("fresh_summary@example.com")
      session = create_session(user)

      {:ok, _} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Fresh summary."
        })

      summary = SessionSummaries.get_fresh_summary(session.id, 60)
      assert summary.content == "Fresh summary."
    end

    test "returns nil if summary is stale" do
      user = create_user("stale_summary@example.com")
      session = create_session(user)

      {:ok, summary} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Old summary."
        })

      # Manually backdate updated_at to simulate staleness
      past = DateTime.add(DateTime.utc_now(), -120, :minute)

      James.Repo.update_all(
        from(s in James.SessionSummaries.SessionSummary, where: s.id == ^summary.id),
        set: [updated_at: past]
      )

      result = SessionSummaries.get_fresh_summary(session.id, 60)
      assert is_nil(result)
    end
  end

  describe "validations" do
    test "requires session_id" do
      assert {:error, changeset} =
               SessionSummaries.create_or_update_summary(%{content: "No session."})

      assert %{session_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires content" do
      user = create_user("no_content_summary@example.com")
      session = create_session(user)

      assert {:error, changeset} =
               SessionSummaries.create_or_update_summary(%{session_id: session.id})

      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_summary/1" do
    test "removes the summary" do
      user = create_user("delete_summary@example.com")
      session = create_session(user)

      {:ok, summary} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "To be deleted."
        })

      assert {:ok, _} = SessionSummaries.delete_summary(summary)
      assert is_nil(SessionSummaries.get_summary(session.id))
    end
  end

  describe "summary_exists?/1" do
    test "returns true when summary exists" do
      user = create_user("exists_summary@example.com")
      session = create_session(user)

      {:ok, _} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Exists."
        })

      assert SessionSummaries.summary_exists?(session.id)
    end

    test "returns false when summary does not exist" do
      user = create_user("not_exists_summary@example.com")
      session = create_session(user)

      refute SessionSummaries.summary_exists?(session.id)
    end
  end

  describe "token count and tool call count" do
    test "stores token_count_at_extraction and tool_calls_at_extraction" do
      user = create_user("token_count_summary@example.com")
      session = create_session(user)
      message = create_message(session)

      {:ok, summary} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Token-rich summary.",
          last_message_id: message.id,
          token_count_at_extraction: 4096,
          tool_calls_at_extraction: 12
        })

      assert summary.token_count_at_extraction == 4096
      assert summary.tool_calls_at_extraction == 12
      assert summary.last_message_id == message.id
    end

    test "defaults token_count_at_extraction and tool_calls_at_extraction to 0" do
      user = create_user("token_defaults_summary@example.com")
      session = create_session(user)

      {:ok, summary} =
        SessionSummaries.create_or_update_summary(%{
          session_id: session.id,
          content: "Default counts."
        })

      assert summary.token_count_at_extraction == 0
      assert summary.tool_calls_at_extraction == 0
    end
  end
end
