defmodule James.Providers.OpenAITest do
  use ExUnit.Case, async: false

  alias James.Providers.OpenAI

  setup do
    original_key = Application.get_env(:james, :openai_api_key)
    original_env = System.get_env("OPENAI_API_KEY")
    original_url = System.get_env("OPENAI_API_URL")

    on_exit(fn ->
      case original_key do
        nil -> Application.delete_env(:james, :openai_api_key)
        v -> Application.put_env(:james, :openai_api_key, v)
      end

      case original_env do
        nil -> System.delete_env("OPENAI_API_KEY")
        v -> System.put_env("OPENAI_API_KEY", v)
      end

      case original_url do
        nil -> System.delete_env("OPENAI_API_URL")
        v -> System.put_env("OPENAI_API_URL", v)
      end
    end)

    :ok
  end

  describe "send_message/2 — no API key" do
    test "returns error when OPENAI_API_KEY is not set" do
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)

      assert {:error, "OPENAI_API_KEY not configured"} =
               OpenAI.send_message([%{role: "user", content: "hi"}])
    end
  end

  describe "stream_message/2 — no API key" do
    test "returns error when OPENAI_API_KEY is not set" do
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)

      assert {:error, "OPENAI_API_KEY not configured"} =
               OpenAI.stream_message([%{role: "user", content: "hi"}])
    end
  end

  describe "send_message/2 — with Bypass" do
    setup do
      bypass = Bypass.open()
      System.put_env("OPENAI_API_URL", "http://localhost:#{bypass.port}")
      System.put_env("OPENAI_API_KEY", "test-openai-key")
      {:ok, bypass: bypass}
    end

    test "returns content on 200 response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        resp =
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => "OpenAI says hello"}, "finish_reason" => "stop"}
            ],
            "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      messages = [%{role: "user", content: "hi"}]
      assert {:ok, %{content: "OpenAI says hello", usage: usage}} = OpenAI.send_message(messages)
      assert usage.input_tokens == 10
      assert usage.output_tokens == 5
    end

    test "returns error on 401 response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => %{"message" => "Invalid API key"}}))
      end)

      assert {:error, reason} = OpenAI.send_message([%{role: "user", content: "hi"}])
      assert reason =~ "401"
    end

    test "sends Authorization Bearer header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        headers = Map.new(conn.req_headers)
        assert String.starts_with?(Map.get(headers, "authorization", ""), "Bearer ")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "choices" => [%{"message" => %{"content" => "ok"}, "finish_reason" => "stop"}],
          "usage" => %{"prompt_tokens" => 1, "completion_tokens" => 1}
        }))
      end)

      OpenAI.send_message([%{role: "user", content: "hi"}])
    end

    test "returns empty content when choices is empty", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "choices" => [],
          "usage" => %{"prompt_tokens" => 1, "completion_tokens" => 0}
        }))
      end)

      assert {:ok, %{content: ""}} = OpenAI.send_message([%{role: "user", content: "hi"}])
    end

    test "prepends system message when :system opt is provided", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        messages = decoded["messages"]
        assert hd(messages)["role"] == "system"
        assert hd(messages)["content"] =~ "be helpful"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "choices" => [%{"message" => %{"content" => "sure"}, "finish_reason" => "stop"}],
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 2}
        }))
      end)

      OpenAI.send_message([%{role: "user", content: "hi"}], system: "be helpful")
    end
  end

end
