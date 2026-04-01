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
end
