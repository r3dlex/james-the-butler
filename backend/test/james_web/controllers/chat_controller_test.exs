defmodule JamesWeb.ChatControllerTest do
  use JamesWeb.ConnCase, async: false

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

  describe "POST /api/chat (create) — with Bypass" do
    setup do
      bypass = Bypass.open()
      original_key = System.get_env("ANTHROPIC_API_KEY")
      original_url = System.get_env("ANTHROPIC_API_URL")

      System.put_env("ANTHROPIC_API_KEY", "test-api-key")
      System.put_env("ANTHROPIC_API_URL", "http://localhost:#{bypass.port}")

      on_exit(fn ->
        case original_key do
          nil -> System.delete_env("ANTHROPIC_API_KEY")
          v -> System.put_env("ANTHROPIC_API_KEY", v)
        end

        case original_url do
          nil -> System.delete_env("ANTHROPIC_API_URL")
          v -> System.put_env("ANTHROPIC_API_URL", v)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "returns 200 and proxies response on success", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        resp = Jason.encode!(%{"id" => "msg_1", "content" => [%{"text" => "Hello!"}]})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      user = create_user("chat_ok@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/chat", %{messages: [%{role: "user", content: "Hi"}]})
      body = json_response(conn, 200)
      assert body["id"] == "msg_1"
    end

    test "returns error status when API returns non-200", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => %{"message" => "bad request"}}))
      end)

      user = create_user("chat_err@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/chat", %{messages: [%{role: "user", content: "Hi"}]})
      body = json_response(conn, 400)
      assert body["error"] =~ "400"
    end

    test "returns 502 when API is unreachable", %{conn: conn, bypass: bypass} do
      Bypass.down(bypass)

      user = create_user("chat_down@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/chat", %{messages: [%{role: "user", content: "Hi"}]})
      assert json_response(conn, 502)["error"] =~ "Failed to reach"
    end
  end
end
