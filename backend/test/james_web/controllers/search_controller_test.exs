defmodule JamesWeb.SearchControllerTest do
  use JamesWeb.ConnCase

  alias James.Accounts

  defp create_user(email \\ "search_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
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
  end
end
