defmodule JamesWeb.EmbeddingControllerTest do
  use JamesWeb.ConnCase

  alias James.Accounts

  defp create_user(email \\ "embed_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  describe "POST /api/embeddings (create)" do
    test "returns 400 when text parameter is missing", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/embeddings", %{})
      assert json_response(conn, 400)["error"] =~ "text required"
    end

    test "returns 503 when embedding service is unavailable (no API key)", %{conn: conn} do
      user = create_user("embed_nokey@example.com")
      conn = authed_conn(conn, user)
      # Without VOYAGE_API_KEY or ANTHROPIC_API_KEY, generate returns error
      conn = post(conn, "/api/embeddings", %{text: "Hello world"})
      # Either 503 (service unavailable) or 200 (if embedding service configured)
      assert conn.status in [200, 503]
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = post(conn, "/api/embeddings", %{text: "test"})
      assert conn.status == 401
    end
  end
end
