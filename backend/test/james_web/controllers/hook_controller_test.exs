defmodule JamesWeb.HookControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Hooks}

  defp create_user(email \\ "hook_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_hook(user, attrs \\ %{}) do
    {:ok, hook} =
      Hooks.create_hook(
        Map.merge(
          %{
            user_id: user.id,
            scope: "session",
            event: "task_start",
            type: "http",
            config: %{url: "https://example.com/webhook"}
          },
          attrs
        )
      )

    hook
  end

  describe "GET /api/hooks (index)" do
    test "returns user's hooks", %{conn: conn} do
      user = create_user()
      create_hook(user)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hooks")
      hooks = json_response(conn, 200)["hooks"]
      assert hooks != []
    end

    test "returns empty list when user has no hooks", %{conn: conn} do
      user = create_user("hook_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hooks")
      assert json_response(conn, 200)["hooks"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/hooks")
      assert conn.status == 401
    end

    test "hook includes expected fields", %{conn: conn} do
      user = create_user("hook_fields@example.com")
      create_hook(user)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hooks")
      [hook] = json_response(conn, 200)["hooks"]
      assert Map.has_key?(hook, "id")
      assert Map.has_key?(hook, "event")
      assert Map.has_key?(hook, "type")
    end
  end

  describe "POST /api/hooks (create)" do
    test "creates a hook for authenticated user", %{conn: conn} do
      user = create_user("hook_create@example.com")
      conn = authed_conn(conn, user)

      conn =
        post(conn, "/api/hooks", %{
          scope: "session",
          event: "task_complete",
          type: "http",
          config: %{url: "https://example.com"}
        })

      assert json_response(conn, 201)["hook"]["event"] == "task_complete"
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/hooks", %{event: "test"})
      assert conn.status == 401
    end
  end

  describe "PUT /api/hooks/:id (update)" do
    test "updates hook config", %{conn: conn} do
      user = create_user("hook_update@example.com")
      hook = create_hook(user)
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/hooks/#{hook.id}", %{enabled: false})
      assert json_response(conn, 200)["hook"]["enabled"] == false
    end

    test "returns 404 for unknown hook", %{conn: conn} do
      user = create_user("hook_upd_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/hooks/#{Ecto.UUID.generate()}", %{enabled: false})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "DELETE /api/hooks/:id (delete)" do
    test "deletes a hook", %{conn: conn} do
      user = create_user("hook_delete@example.com")
      hook = create_hook(user)
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/hooks/#{hook.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown hook", %{conn: conn} do
      user = create_user("hook_del_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/hooks/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
