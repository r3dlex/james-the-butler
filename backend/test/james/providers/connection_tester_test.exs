defmodule James.Providers.ConnectionTesterTest do
  use ExUnit.Case, async: true

  alias James.Providers.ConnectionTester
  alias James.Providers.ProviderConfig

  # Build a bare ProviderConfig struct without hitting the database.
  defp anthropic_config(overrides \\ %{}) do
    base = %ProviderConfig{
      provider_type: "anthropic",
      display_name: "Test Anthropic",
      decrypted_api_key: "sk-ant-test",
      base_url: nil
    }

    Map.merge(base, overrides)
  end

  defp ollama_config(base_url) do
    %ProviderConfig{
      provider_type: "ollama",
      display_name: "Test Ollama",
      base_url: base_url
    }
  end

  # ---------------------------------------------------------------------------
  # Anthropic (cloud) — success
  # ---------------------------------------------------------------------------

  describe "test_connection/1 — Anthropic success" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns {:ok, %{status: :connected, latency_ms: n}} for 200 response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "content" => [%{"type" => "text", "text" => "hi"}],
            "usage" => %{"input_tokens" => 1, "output_tokens" => 1}
          })
        )
      end)

      config = anthropic_config(%{base_url: "http://localhost:#{bypass.port}"})
      assert {:ok, result} = ConnectionTester.test_connection(config)
      assert result.status == :connected
      assert is_integer(result.latency_ms)
      assert result.latency_ms >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # Anthropic — 401 invalid API key
  # ---------------------------------------------------------------------------

  describe "test_connection/1 — Anthropic 401" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns {:error, %{status: :failed, reason: 'invalid_api_key'}} for 401", %{
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => %{"message" => "Unauthorized"}}))
      end)

      config = anthropic_config(%{base_url: "http://localhost:#{bypass.port}"})
      assert {:error, result} = ConnectionTester.test_connection(config)
      assert result.status == :failed
      assert result.reason == "invalid_api_key"
    end
  end

  # ---------------------------------------------------------------------------
  # Anthropic — 429 rate limited
  # ---------------------------------------------------------------------------

  describe "test_connection/1 — Anthropic 429" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns {:error, %{status: :failed, reason: 'rate_limited'}} for 429", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          429,
          Jason.encode!(%{"error" => %{"message" => "Too many requests"}})
        )
      end)

      config = anthropic_config(%{base_url: "http://localhost:#{bypass.port}"})
      assert {:error, result} = ConnectionTester.test_connection(config)
      assert result.status == :failed
      assert result.reason == "rate_limited"
    end
  end

  # ---------------------------------------------------------------------------
  # Anthropic — connection refused (network error)
  # ---------------------------------------------------------------------------

  describe "test_connection/1 — Anthropic network error" do
    test "returns {:error, %{status: :failed, reason: 'network_error'}} when connection refused" do
      # Port 1 is guaranteed to be refused on any normal system
      config = anthropic_config(%{base_url: "http://localhost:1"})
      assert {:error, result} = ConnectionTester.test_connection(config)
      assert result.status == :failed
      assert result.reason == "network_error"
    end
  end

  # ---------------------------------------------------------------------------
  # Ollama (local) — success
  # ---------------------------------------------------------------------------

  describe "test_connection/1 — Ollama success" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns {:ok, %{status: :connected}} when endpoint responds", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "Ollama is running")
      end)

      config = ollama_config("http://localhost:#{bypass.port}")
      assert {:ok, result} = ConnectionTester.test_connection(config)
      assert result.status == :connected
      assert is_integer(result.latency_ms)
    end
  end

  # ---------------------------------------------------------------------------
  # Ollama (local) — unreachable
  # ---------------------------------------------------------------------------

  describe "test_connection/1 — Ollama unreachable" do
    test "returns {:error, %{status: :failed, reason: 'network_error'}} when endpoint is down" do
      config = ollama_config("http://localhost:1")
      assert {:error, result} = ConnectionTester.test_connection(config)
      assert result.status == :failed
      assert result.reason == "network_error"
    end
  end
end
