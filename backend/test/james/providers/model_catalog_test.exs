defmodule James.Providers.ModelCatalogTest do
  use ExUnit.Case, async: true

  alias James.Providers.ModelCatalog

  # ---------------------------------------------------------------------------
  # Cloud providers — hardcoded lists
  # ---------------------------------------------------------------------------

  describe "list_models/1 — anthropic" do
    test "returns known Claude models" do
      assert {:ok, models} = ModelCatalog.list_models("anthropic")
      assert is_list(models)
      assert Enum.any?(models, &String.starts_with?(&1, "claude-"))
    end
  end

  describe "list_models/1 — openai" do
    test "returns known GPT models" do
      assert {:ok, models} = ModelCatalog.list_models("openai")
      assert is_list(models)
      assert Enum.any?(models, &String.starts_with?(&1, "gpt-"))
    end
  end

  describe "list_models/1 — gemini" do
    test "returns known Gemini models" do
      assert {:ok, models} = ModelCatalog.list_models("gemini")
      assert is_list(models)
      assert Enum.any?(models, &String.starts_with?(&1, "gemini-"))
    end
  end

  describe "list_models/1 — minimax" do
    test "returns known MiniMax models" do
      assert {:ok, models} = ModelCatalog.list_models("minimax")
      assert is_list(models)
      assert Enum.any?(models, &String.starts_with?(&1, "abab"))
    end
  end

  # ---------------------------------------------------------------------------
  # Ollama — dynamic from /api/tags
  # ---------------------------------------------------------------------------

  describe "list_models/2 — ollama success" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "queries GET /api/tags and returns model names", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/tags", fn conn ->
        body =
          Jason.encode!(%{
            "models" => [
              %{"name" => "llama3:latest"},
              %{"name" => "mistral:7b"}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, models} = ModelCatalog.list_models("ollama", "http://localhost:#{bypass.port}")
      assert "llama3:latest" in models
      assert "mistral:7b" in models
    end
  end

  # ---------------------------------------------------------------------------
  # LM Studio — dynamic from /v1/models
  # ---------------------------------------------------------------------------

  describe "list_models/2 — lm_studio success" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "queries GET /v1/models and returns model IDs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/models", fn conn ->
        body =
          Jason.encode!(%{
            "data" => [
              %{"id" => "TheBloke/Llama-2-7B-GGUF"},
              %{"id" => "mistralai/Mistral-7B-v0.1"}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, models} =
               ModelCatalog.list_models("lm_studio", "http://localhost:#{bypass.port}")

      assert "TheBloke/Llama-2-7B-GGUF" in models
      assert "mistralai/Mistral-7B-v0.1" in models
    end
  end

  # ---------------------------------------------------------------------------
  # OpenAI Compatible — dynamic from /v1/models
  # ---------------------------------------------------------------------------

  describe "list_models/2 — openai_compatible success" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "queries GET /v1/models and returns model IDs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/v1/models", fn conn ->
        body =
          Jason.encode!(%{
            "data" => [
              %{"id" => "local-model-1"},
              %{"id" => "local-model-2"}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, models} =
               ModelCatalog.list_models("openai_compatible", "http://localhost:#{bypass.port}")

      assert "local-model-1" in models
      assert "local-model-2" in models
    end
  end

  # ---------------------------------------------------------------------------
  # Unreachable local endpoint
  # ---------------------------------------------------------------------------

  describe "list_models/2 — unreachable endpoint" do
    test "returns {:error, 'network_error'} for ollama when endpoint is down" do
      assert {:error, "network_error"} = ModelCatalog.list_models("ollama", "http://localhost:1")
    end

    test "returns {:error, 'network_error'} for lm_studio when endpoint is down" do
      assert {:error, "network_error"} =
               ModelCatalog.list_models("lm_studio", "http://localhost:1")
    end

    test "returns {:error, 'network_error'} for openai_compatible when endpoint is down" do
      assert {:error, "network_error"} =
               ModelCatalog.list_models("openai_compatible", "http://localhost:1")
    end
  end
end
