defmodule JamesWeb.TokenControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Hosts, Sessions, Tokens}

  defp create_user(email \\ "token_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, host} = Hosts.create_host(%{name: "Token Host", endpoint: "http://localhost:7055"})
    {:ok, session} = Sessions.create_session(%{user_id: user.id, host_id: host.id})
    session
  end

  describe "GET /api/tokens/usage (usage)" do
    test "returns token usage list", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tokens/usage")
      assert conn.status == 200
      assert Map.has_key?(json_response(conn, 200), "usage")
    end

    test "returns empty list when no usage recorded", %{conn: conn} do
      user = create_user("token_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tokens/usage")
      assert json_response(conn, 200)["usage"] == []
    end

    test "returns recorded usage entries", %{conn: conn} do
      user = create_user("token_recorded@example.com")
      session = create_session(user)

      {:ok, _} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "claude-3-haiku",
          input_tokens: 100,
          output_tokens: 50,
          cost_usd: Decimal.new("0.001")
        })

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tokens/usage?session_id=#{session.id}")
      usage = json_response(conn, 200)["usage"]
      assert length(usage) == 1
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/tokens/usage")
      assert conn.status == 401
    end
  end

  describe "GET /api/tokens/usage/summary (summary)" do
    test "returns usage summary grouped by model", %{conn: conn} do
      user = create_user("token_summary@example.com")
      session = create_session(user)

      {:ok, _} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "gpt-4o",
          input_tokens: 200,
          output_tokens: 80,
          cost_usd: Decimal.new("0.005")
        })

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tokens/usage/summary")
      assert conn.status == 200
      assert Map.has_key?(json_response(conn, 200), "summary")
    end

    test "returns empty summary when no usage", %{conn: conn} do
      user = create_user("token_summary_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tokens/usage/summary")
      assert json_response(conn, 200)["summary"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/tokens/usage/summary")
      assert conn.status == 401
    end
  end
end
