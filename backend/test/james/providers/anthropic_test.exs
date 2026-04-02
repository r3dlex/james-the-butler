defmodule James.Providers.AnthropicTest do
  use ExUnit.Case, async: false

  alias James.Providers.Anthropic

  setup do
    original_key = Application.get_env(:james, :anthropic_api_key)
    original_env = System.get_env("ANTHROPIC_API_KEY")
    original_url = System.get_env("ANTHROPIC_API_URL")

    Application.delete_env(:james, :anthropic_api_key)
    System.delete_env("ANTHROPIC_API_KEY")

    on_exit(fn ->
      case original_key do
        nil -> Application.delete_env(:james, :anthropic_api_key)
        v -> Application.put_env(:james, :anthropic_api_key, v)
      end

      case original_env do
        nil -> System.delete_env("ANTHROPIC_API_KEY")
        v -> System.put_env("ANTHROPIC_API_KEY", v)
      end

      case original_url do
        nil -> System.delete_env("ANTHROPIC_API_URL")
        v -> System.put_env("ANTHROPIC_API_URL", v)
      end
    end)

    :ok
  end

  describe "stream_message/2 — no API key" do
    test "returns error when ANTHROPIC_API_KEY is not configured" do
      assert {:error, reason} = Anthropic.stream_message([%{role: "user", content: "hi"}])
      assert reason =~ "not configured"
    end

    test "returns error tuple for empty messages list when no key is set" do
      assert {:error, _} = Anthropic.stream_message([])
    end
  end

  describe "send_message/2 — no API key" do
    test "returns error when ANTHROPIC_API_KEY is not configured" do
      assert {:error, reason} = Anthropic.send_message([%{role: "user", content: "hello"}])
      assert reason =~ "not configured"
    end
  end

  describe "send_message/2 — api_key and base_url from opts (per-user config)" do
    test "uses :api_key opt instead of env var" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        headers = Map.new(conn.req_headers)
        assert headers["x-api-key"] == "opts-key"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "content" => [%{"type" => "text", "text" => "ok"}],
            "usage" => %{"input_tokens" => 1, "output_tokens" => 1}
          })
        )
      end)

      url = "http://localhost:#{bypass.port}"

      assert {:ok, %{content: "ok"}} =
               Anthropic.send_message([%{role: "user", content: "hi"}],
                 api_key: "opts-key",
                 base_url: url
               )
    end

    test "uses :base_url opt to route to a custom endpoint" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "content" => [%{"type" => "text", "text" => "minimax-ok"}],
            "usage" => %{"input_tokens" => 1, "output_tokens" => 1}
          })
        )
      end)

      url = "http://localhost:#{bypass.port}"

      assert {:ok, %{content: "minimax-ok"}} =
               Anthropic.send_message([%{role: "user", content: "hi"}],
                 api_key: "test-key",
                 base_url: url
               )
    end

    test "still returns error when no api_key in opts and none in env" do
      assert {:error, reason} =
               Anthropic.send_message([%{role: "user", content: "hi"}], base_url: "http://x")

      assert reason =~ "not configured"
    end
  end

  describe "send_message/2 — with Bypass" do
    setup do
      bypass = Bypass.open()
      System.put_env("ANTHROPIC_API_URL", "http://localhost:#{bypass.port}")
      System.put_env("ANTHROPIC_API_KEY", "test-key-bypass")
      {:ok, bypass: bypass}
    end

    test "returns content on 200 response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        resp =
          Jason.encode!(%{
            "content" => [%{"type" => "text", "text" => "Hello from mock"}],
            "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      messages = [%{role: "user", content: "hi"}]
      assert {:ok, %{content: "Hello from mock", usage: usage}} = Anthropic.send_message(messages)
      assert usage.input_tokens == 10
      assert usage.output_tokens == 5
    end

    test "returns error on 4xx response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => %{"message" => "Unauthorized"}}))
      end)

      messages = [%{role: "user", content: "hi"}]
      assert {:error, reason} = Anthropic.send_message(messages)
      assert reason =~ "401"
    end

    test "sends x-api-key and anthropic-version headers", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        headers = Map.new(conn.req_headers)
        assert Map.has_key?(headers, "x-api-key")
        assert Map.has_key?(headers, "anthropic-version")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "content" => [%{"type" => "text", "text" => "ok"}],
            "usage" => %{"input_tokens" => 1, "output_tokens" => 1}
          })
        )
      end)

      Anthropic.send_message([%{role: "user", content: "hi"}])
    end

    test "returns empty content when response has no content array", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "content" => [],
            "usage" => %{"input_tokens" => 1, "output_tokens" => 0}
          })
        )
      end)

      assert {:ok, %{content: ""}} = Anthropic.send_message([%{role: "user", content: "hi"}])
    end
  end
end
