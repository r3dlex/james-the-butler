defmodule James.Providers.OpenAICompatibleTest do
  @moduledoc """
  Tests for the OpenAI-compatible generic provider.
  """
  use ExUnit.Case, async: false

  alias James.Providers.OpenAICompatible

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

  describe "send_message/2 — delegates to OpenAI with configurable base_url" do
    setup do
      bypass = Bypass.open()
      System.put_env("OPENAI_API_KEY", "test-compat-key")
      System.delete_env("OPENAI_API_URL")
      {:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
    end

    test "uses provided base_url instead of default OpenAI URL", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        resp =
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => "Compatible response"}, "finish_reason" => "stop"}
            ],
            "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 8}
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, resp)
      end)

      messages = [%{role: "user", content: "hi"}]

      assert {:ok, %{content: "Compatible response", usage: usage}} =
               OpenAICompatible.send_message(messages, base_url: base_url)

      assert usage.input_tokens == 5
      assert usage.output_tokens == 8
    end

    test "passes through optional :api_key in opts", %{bypass: bypass, base_url: base_url} do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        headers = Map.new(conn.req_headers)
        assert String.starts_with?(Map.get(headers, "authorization", ""), "Bearer custom-key")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "choices" => [%{"message" => %{"content" => "ok"}, "finish_reason" => "stop"}],
            "usage" => %{"prompt_tokens" => 1, "completion_tokens" => 1}
          })
        )
      end)

      OpenAICompatible.send_message(
        [%{role: "user", content: "hi"}],
        base_url: base_url,
        api_key: "custom-key"
      )
    end

    test "custom base_url works for LM Studio style endpoints", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => "LM Studio response"}, "finish_reason" => "stop"}
            ],
            "usage" => %{"prompt_tokens" => 3, "completion_tokens" => 4}
          })
        )
      end)

      assert {:ok, %{content: "LM Studio response"}} =
               OpenAICompatible.send_message(
                 [%{role: "user", content: "hi"}],
                 base_url: base_url,
                 model: "local-model"
               )
    end
  end

  describe "send_message/2 — Ollama: no API key required" do
    setup do
      bypass = Bypass.open()
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)
      {:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
    end

    test "succeeds without an API key when no_auth: true is set", %{
      bypass: bypass,
      base_url: base_url
    } do
      Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => "Ollama says hello"}, "finish_reason" => "stop"}
            ],
            "usage" => %{"prompt_tokens" => 2, "completion_tokens" => 3}
          })
        )
      end)

      assert {:ok, %{content: "Ollama says hello"}} =
               OpenAICompatible.send_message(
                 [%{role: "user", content: "hello"}],
                 base_url: base_url,
                 no_auth: true
               )
    end
  end

  describe "stream_message/2 — passes base_url through" do
    test "returns error when no API key and no_auth not set" do
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)

      assert {:error, _} =
               OpenAICompatible.stream_message(
                 [%{role: "user", content: "hi"}],
                 base_url: "http://localhost:11434"
               )
    end

    test "returns no-key error is bypassed by no_auth: true but still needs network" do
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)

      # With no_auth: true and an unreachable URL, expect a connection error (not an auth error)
      assert {:error, reason} =
               OpenAICompatible.stream_message(
                 [%{role: "user", content: "hi"}],
                 base_url: "http://localhost:1",
                 no_auth: true
               )

      # The error should be a network error, not a "not configured" message
      refute is_binary(reason) and reason =~ "not configured"
    end
  end
end
