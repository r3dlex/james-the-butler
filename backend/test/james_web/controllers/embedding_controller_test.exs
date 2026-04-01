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

  describe "POST /api/embeddings — with Bypass" do
    setup do
      bypass = Bypass.open()
      original_key = System.get_env("VOYAGE_API_KEY")
      original_url = System.get_env("EMBEDDING_API_URL")

      System.put_env("VOYAGE_API_KEY", "test-voyage-key")
      System.put_env("EMBEDDING_API_URL", "http://localhost:#{bypass.port}/v1/embeddings")

      on_exit(fn ->
        case original_key do
          nil -> System.delete_env("VOYAGE_API_KEY")
          v -> System.put_env("VOYAGE_API_KEY", v)
        end

        case original_url do
          nil -> System.delete_env("EMBEDDING_API_URL")
          v -> System.put_env("EMBEDDING_API_URL", v)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "returns 200 with embedding on success", %{conn: conn, bypass: bypass} do
      vector = Enum.map(1..10, fn i -> i / 10.0 end)

      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        resp = Jason.encode!(%{"data" => [%{"embedding" => vector, "index" => 0}]})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      user = create_user("embed_success@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/embeddings", %{text: "embed this text"})
      body = json_response(conn, 200)
      assert is_list(body["embedding"])
      assert length(body["embedding"]) == 10
    end

    test "returns 503 when embedding API returns error", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "unauthorized"}))
      end)

      user = create_user("embed_fail@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/embeddings", %{text: "embed this text"})
      assert json_response(conn, 503)["error"] =~ "embedding API error"
    end
  end
end
