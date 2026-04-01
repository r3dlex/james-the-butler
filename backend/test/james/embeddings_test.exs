defmodule James.EmbeddingsTest do
  use ExUnit.Case, async: false

  alias James.Embeddings

  setup do
    # Clear API key env vars so tests run in predictable no-key state
    original_voyage = System.get_env("VOYAGE_API_KEY")
    original_anthropic = Application.get_env(:james, :anthropic_api_key)

    System.delete_env("VOYAGE_API_KEY")
    Application.delete_env(:james, :anthropic_api_key)

    on_exit(fn ->
      case original_voyage do
        nil -> System.delete_env("VOYAGE_API_KEY")
        v -> System.put_env("VOYAGE_API_KEY", v)
      end

      case original_anthropic do
        nil -> Application.delete_env(:james, :anthropic_api_key)
        v -> Application.put_env(:james, :anthropic_api_key, v)
      end
    end)

    :ok
  end

  describe "generate/1 — no API key" do
    test "returns error when no embedding API key is configured" do
      assert {:error, reason} = Embeddings.generate("some text")
      assert reason =~ "not configured"
    end

    test "returns error tuple for empty text when no key is set" do
      assert {:error, _} = Embeddings.generate("")
    end
  end

  describe "generate_batch/1 — no API key" do
    test "returns error when no embedding API key is configured" do
      assert {:error, reason} = Embeddings.generate_batch(["text one", "text two"])
      assert reason =~ "not configured"
    end

    test "returns error for an empty list when no key is set" do
      assert {:error, _} = Embeddings.generate_batch([])
    end
  end

  describe "generate/1 — with Bypass" do
    setup do
      bypass = Bypass.open()
      System.put_env("VOYAGE_API_KEY", "test-voyage-key")
      System.put_env("EMBEDDING_API_URL", "http://localhost:#{bypass.port}/v1/embeddings")

      on_exit(fn ->
        System.delete_env("VOYAGE_API_KEY")
        System.delete_env("EMBEDDING_API_URL")
      end)

      {:ok, bypass: bypass}
    end

    test "returns embedding vector on 200 response", %{bypass: bypass} do
      vector = Enum.map(1..10, fn i -> i / 10.0 end)

      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        resp =
          Jason.encode!(%{
            "data" => [%{"embedding" => vector, "index" => 0}],
            "model" => "voyage-3"
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      assert {:ok, result} = Embeddings.generate("hello world")
      assert is_list(result)
      assert length(result) == 10
    end

    test "returns error on non-200 response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, reason} = Embeddings.generate("test")
      assert reason =~ "embedding API error"
    end

    test "sends Authorization Bearer header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        headers = Map.new(conn.req_headers)
        assert String.starts_with?(Map.get(headers, "authorization", ""), "Bearer ")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [%{"embedding" => [0.1, 0.2], "index" => 0}]
        }))
      end)

      Embeddings.generate("test text")
    end
  end

  describe "generate_batch/1 — with Bypass" do
    setup do
      bypass = Bypass.open()
      System.put_env("VOYAGE_API_KEY", "test-voyage-key")
      System.put_env("EMBEDDING_API_URL", "http://localhost:#{bypass.port}/v1/embeddings")

      on_exit(fn ->
        System.delete_env("VOYAGE_API_KEY")
        System.delete_env("EMBEDDING_API_URL")
      end)

      {:ok, bypass: bypass}
    end

    test "returns list of embedding vectors on 200 response", %{bypass: bypass} do
      v1 = [0.1, 0.2, 0.3]
      v2 = [0.4, 0.5, 0.6]

      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        resp =
          Jason.encode!(%{
            "data" => [
              %{"embedding" => v1, "index" => 0},
              %{"embedding" => v2, "index" => 1}
            ],
            "model" => "voyage-3"
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      assert {:ok, [r1, r2]} = Embeddings.generate_batch(["hello", "world"])
      assert r1 == v1
      assert r2 == v2
    end

    test "returns embeddings in correct index order", %{bypass: bypass} do
      v0 = [1.0, 0.0]
      v1 = [0.0, 1.0]

      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        # Return in reversed order to verify sorting
        resp =
          Jason.encode!(%{
            "data" => [
              %{"embedding" => v1, "index" => 1},
              %{"embedding" => v0, "index" => 0}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      assert {:ok, [r0, r1]} = Embeddings.generate_batch(["first", "second"])
      assert r0 == v0
      assert r1 == v1
    end

    test "returns error on API error response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/embeddings", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, reason} = Embeddings.generate_batch(["a", "b"])
      assert reason =~ "embedding API error"
    end
  end
end
