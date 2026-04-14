defmodule JamesWeb.EmbeddingControllerTest do
  use JamesWeb.ConnCase, async: false

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

    test "returns 200 with 384-dim embedding (Bumblebee fallback)", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/embeddings", %{text: "Hello world"})
      body = json_response(conn, 200)
      assert is_list(body["embedding"])
      assert length(body["embedding"]) == 384
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = post(conn, "/api/embeddings", %{text: "test"})
      assert conn.status == 401
    end
  end
end
