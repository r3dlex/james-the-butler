defmodule James.EmbeddingsTest do
  use ExUnit.Case

  alias James.Embeddings

  describe "generate/1" do
    test "returns a 384-element float list" do
      {:ok, embedding} = Embeddings.generate("hello world")
      assert is_list(embedding)
      assert length(embedding) == 384
      assert Enum.all?(embedding, &is_float/1)
    end

    test "returns same embedding for same text" do
      {:ok, e1} = Embeddings.generate("hello world")
      {:ok, e2} = Embeddings.generate("hello world")
      assert e1 == e2
    end

    test "handles empty string" do
      {:ok, embedding} = Embeddings.generate("")
      assert is_list(embedding)
      assert length(embedding) == 384
    end

    test "handles unicode text" do
      {:ok, embedding} = Embeddings.generate("日本語テスト")
      assert is_list(embedding)
      assert length(embedding) == 384
    end
  end

  describe "generate_batch/1" do
    test "returns list of 384-element float lists" do
      {:ok, embeddings} = Embeddings.generate_batch(["hello", "world", "test"])
      assert is_list(embeddings)
      assert length(embeddings) == 3
      assert Enum.all?(embeddings, fn e -> is_list(e) and length(e) == 384 end)
    end

    test "returns same embeddings for same texts" do
      {:ok, e1} = Embeddings.generate_batch(["a", "b"])
      {:ok, e2} = Embeddings.generate_batch(["a", "b"])
      assert e1 == e2
    end

    test "handles empty list" do
      {:ok, embeddings} = Embeddings.generate_batch([])
      assert embeddings == []
    end

    test "handles single-item list" do
      {:ok, [embedding]} = Embeddings.generate_batch(["only one"])
      assert length(embedding) == 384
    end
  end
end
