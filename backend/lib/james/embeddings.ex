defmodule James.Embeddings do
  @moduledoc """
  Generates vector embeddings using Bumblebee + Nx locally.
  Falls back to a zero vector when Bumblebee is unavailable.
  Used by memory extraction, document chunking, and the /embeddings endpoint.
  """

  require Logger

  @model_id "sentence-transformers/all-MiniLM-L6-v2"
  @dimension 384

  @doc """
  Generate an embedding vector for the given text.
  Returns `{:ok, [float()]}`.
  """
  def generate(text) when is_binary(text) do
    serving = fetch_or_start_serving()

    if serving do
      embedding = Bumblebee.Text.text_embedding(serving, text).embedding
      {:ok, Nx.to_list(embedding)}
    else
      Logger.warning("Bumblebee unavailable, returning zeros")
      {:ok, List.duplicate(0.0, @dimension)}
    end
  end

  @doc """
  Generate embeddings for multiple texts.
  Returns `{:ok, [[float()]]}`.
  """
  def generate_batch(texts) when is_list(texts) do
    serving = fetch_or_start_serving()

    if serving do
      embeddings =
        texts
        |> Enum.map(&Bumblebee.Text.text_embedding(serving, &1))
        |> Enum.map(&Nx.to_list(&1.embedding))

      {:ok, embeddings}
    else
      Logger.warning("Bumblebee unavailable, returning zeros")
      {:ok, List.duplicate(List.duplicate(0.0, @dimension), length(texts))}
    end
  end

  # Check cache — :none means we tried and failed (don't retry), nil means not yet tried
  defp fetch_or_start_serving do
    case Process.get(__MODULE__) do
      nil -> load_and_cache_serving()
      :none -> nil
      serving -> serving
    end
  end

  defp load_and_cache_serving do
    try do
      model_info = Bumblebee.load_model({:hf, @model_id})
      tokenizer = Bumblebee.load_tokenizer({:hf, @model_id})
      serving = Bumblebee.Text.text_embedding(model_info, tokenizer)
      Process.put(__MODULE__, serving)
      serving
    rescue
      e ->
        Logger.warning("Bumblebee unavailable: #{inspect(e)}")
        Process.put(__MODULE__, :none)
        nil
    end
  end
end
