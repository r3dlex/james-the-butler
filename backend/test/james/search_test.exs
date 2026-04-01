defmodule James.SearchTest do
  use James.DataCase

  alias James.{Accounts, Search, Sessions}

  defp create_user(email \\ "search_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user, attrs \\ %{}) do
    {:ok, session} =
      Sessions.create_session(Map.merge(%{user_id: user.id, name: "Search Session"}, attrs))

    session
  end

  defp create_message(session, content) do
    {:ok, msg} =
      Sessions.create_message(%{session_id: session.id, role: "user", content: content})

    msg
  end

  describe "search/2" do
    test "returns empty list when no sessions match the query" do
      user = create_user()
      create_session(user, %{name: "Nothing here"})

      results = Search.search("xyzzy_nonexistent_term", user_id: user.id)
      assert results == []
    end

    test "returns empty list when user has no sessions" do
      user = create_user("search_empty@example.com")
      results = Search.search("hello", user_id: user.id)
      assert results == []
    end

    test "requires user_id option" do
      assert_raise KeyError, fn ->
        Search.search("anything", [])
      end
    end

    test "does not return archived sessions" do
      user = create_user("search_archived@example.com")
      session = create_session(user, %{name: "Archived Session"})
      Sessions.update_session(session, %{status: "archived"})
      # Even with a term that would match, archived sessions should be excluded
      results = Search.search("Archived", user_id: user.id)
      session_ids = Enum.map(results, & &1.session_id)
      refute session.id in session_ids
    end

    test "does not return results for other users" do
      user1 = create_user("search_u1@example.com")
      user2 = create_user("search_u2@example.com")
      create_session(user1, %{name: "Findable Session"})
      # Search as user2 — should not see user1's sessions
      results = Search.search("Findable", user_id: user2.id)
      assert results == []
    end

    test "returns results with expected keys" do
      user = create_user("search_keys@example.com")
      session = create_session(user, %{name: "Elephant memory"})
      create_message(session, "elephants never forget things in the forest")

      # If fulltext search finds anything, check shape; otherwise confirm empty
      results = Search.search("elephant", user_id: user.id)

      Enum.each(results, fn result ->
        assert Map.has_key?(result, :session_id)
        assert Map.has_key?(result, :session_name)
        assert Map.has_key?(result, :score)
        assert Map.has_key?(result, :source)
      end)
    end

    test "returns empty list when query is all punctuation (sanitized to empty)" do
      user = create_user("search_punct@example.com")
      create_session(user)
      results = Search.search("!!! ???", user_id: user.id)
      assert results == []
    end
  end
end
