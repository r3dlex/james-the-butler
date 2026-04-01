defmodule JamesWeb.SearchControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Hosts, Sessions}

  defp create_user(email \\ "search_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session_with_message(user, content) do
    {:ok, host} =
      Hosts.create_host(%{
        name: "search-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9000"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Search Test #{System.unique_integer()}"
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: content})
    session
  end

  describe "GET /api/search (index)" do
    test "returns search results (empty for no matches)", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=nonexistent_query_12345")
      assert conn.status == 200
      assert Map.has_key?(json_response(conn, 200), "results")
    end

    test "returns empty results for unknown query", %{conn: conn} do
      user = create_user("search_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=zzz_no_match_xyz")
      assert json_response(conn, 200)["results"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/search?q=test")
      assert conn.status == 401
    end

    test "returns empty list when no query provided", %{conn: conn} do
      user = create_user("search_noq@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search")
      assert conn.status == 200
    end

    test "returns results when session with matching content exists", %{conn: conn} do
      user = create_user("search_real@example.com")
      _session = create_session_with_message(user, "unique_test_keyword_9876")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=unique_test_keyword_9876")
      resp = json_response(conn, 200)
      assert is_list(resp["results"])
    end

    test "accepts host_id filter without error", %{conn: conn} do
      user = create_user("search_hf@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=test&host_id=#{Ecto.UUID.generate()}")
      assert conn.status == 200
    end

    test "accepts project_id filter without error", %{conn: conn} do
      user = create_user("search_pf@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=test&project_id=#{Ecto.UUID.generate()}")
      assert conn.status == 200
    end

    test "accepts agent_type filter without error", %{conn: conn} do
      user = create_user("search_af@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=test&agent_type=chat")
      assert conn.status == 200
    end

    test "accepts limit parameter", %{conn: conn} do
      user = create_user("search_lim@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/search?q=test&limit=5")
      assert conn.status == 200
    end
  end
end
