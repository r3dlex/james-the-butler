defmodule JamesWeb.MemoryControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Memories}

  defp create_user(email \\ "mem_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_memory(user, attrs \\ %{}) do
    {:ok, memory} =
      Memories.create_memory(Map.merge(%{user_id: user.id, content: "Important insight"}, attrs))

    memory
  end

  describe "GET /api/memories (index)" do
    test "returns user's memories", %{conn: conn} do
      user = create_user()
      create_memory(user, %{content: "My memory"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/memories")
      memories = json_response(conn, 200)["memories"]
      assert memories != []
    end

    test "returns empty list when user has no memories", %{conn: conn} do
      user = create_user("mem_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/memories")
      assert json_response(conn, 200)["memories"] == []
    end

    test "does not return other users' memories", %{conn: conn} do
      user1 = create_user("mem_u1@example.com")
      user2 = create_user("mem_u2@example.com")
      create_memory(user2)
      conn = authed_conn(conn, user1)
      conn = get(conn, "/api/memories")
      assert json_response(conn, 200)["memories"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/memories")
      assert conn.status == 401
    end

    test "memory includes expected fields", %{conn: conn} do
      user = create_user("mem_fields@example.com")
      create_memory(user, %{content: "A fact"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/memories")
      [mem] = json_response(conn, 200)["memories"]
      assert Map.has_key?(mem, "id")
      assert Map.has_key?(mem, "content")
    end
  end

  describe "GET /api/memories?q=search+term (search)" do
    test "returns filtered memories matching query", %{conn: conn} do
      user = create_user("mem_search@example.com")
      create_memory(user, %{content: "User prefers Elixir programming"})
      create_memory(user, %{content: "User works on Phoenix projects"})
      create_memory(user, %{content: "Completely unrelated note"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/memories?q=Elixir")
      memories = json_response(conn, 200)["memories"]
      assert length(memories) == 1
      assert hd(memories)["content"] =~ "Elixir"
    end

    test "returns empty list when no memories match query", %{conn: conn} do
      user = create_user("mem_search_empty@example.com")
      create_memory(user, %{content: "Some memory about Elixir"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/memories?q=Ruby")
      assert json_response(conn, 200)["memories"] == []
    end

    test "search is case-insensitive", %{conn: conn} do
      user = create_user("mem_search_case@example.com")
      create_memory(user, %{content: "User likes ELIXIR"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/memories?q=elixir")
      memories = json_response(conn, 200)["memories"]
      assert length(memories) == 1
    end

    test "requires authentication for search", %{conn: conn} do
      conn = get(conn, "/api/memories?q=anything")
      assert conn.status == 401
    end
  end

  describe "PUT /api/memories/:id (update)" do
    test "updates memory content", %{conn: conn} do
      user = create_user("mem_update@example.com")
      memory = create_memory(user, %{content: "Old content"})
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/memories/#{memory.id}", %{content: "Updated content"})
      assert json_response(conn, 200)["memory"]["content"] == "Updated content"
    end

    test "returns 404 for unknown memory", %{conn: conn} do
      user = create_user("mem_upd_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/memories/#{Ecto.UUID.generate()}", %{content: "x"})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "DELETE /api/memories/:id (delete)" do
    test "deletes a memory", %{conn: conn} do
      user = create_user("mem_delete@example.com")
      memory = create_memory(user, %{content: "Delete me"})
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/memories/#{memory.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown memory", %{conn: conn} do
      user = create_user("mem_del_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/memories/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
