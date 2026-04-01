defmodule JamesWeb.ChatControllerTest do
  use JamesWeb.ConnCase

  alias James.Accounts

  defp create_user(email \\ "chat_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  describe "POST /api/chat (create)" do
    test "returns 400 when messages parameter is missing", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/chat", %{not_messages: "oops"})
      assert json_response(conn, 400)["error"] =~ "Missing"
    end

    test "returns 500 when API key is not configured", %{conn: conn} do
      # In test env, ANTHROPIC_API_KEY is not set
      original = System.get_env("ANTHROPIC_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      user = create_user("chat_nokey@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/chat", %{messages: [%{role: "user", content: "Hello"}]})
      body = json_response(conn, 500)
      assert body["error"] =~ "not configured"

      if original, do: System.put_env("ANTHROPIC_API_KEY", original)
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = post(conn, "/api/chat", %{messages: []})
      assert conn.status == 401
    end
  end
end
