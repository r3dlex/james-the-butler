defmodule James.Embeddings do
  @moduledoc """
  Generates vector embeddings using the configured embedding API.
  Used by memory extraction, document chunking, and the /embeddings endpoint.
  """

  @doc """
  Generate an embedding vector for the given text.
  Returns `{:ok, [float()]}` or `{:error, reason}`.
  """
  def generate(text) when is_binary(text) do
    api_key = embedding_api_key()

    if is_nil(api_key) do
      {:error, "embedding service not configured"}
    else
      case Req.post(embedding_url(),
             headers: [{"Authorization", "Bearer #{api_key}"}],
             json: %{input: [text], model: embedding_model()}
           ) do
        {:ok, %{status: 200, body: %{"data" => [%{"embedding" => embedding} | _]}}} ->
          {:ok, embedding}

        {:ok, %{body: body}} ->
          {:error, "embedding API error: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "embedding request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Generate embeddings for multiple texts in a single API call.
  Returns `{:ok, [[float()]]}` or `{:error, reason}`.
  """
  def generate_batch(texts) when is_list(texts) do
    api_key = embedding_api_key()

    if is_nil(api_key) do
      {:error, "embedding service not configured"}
    else
      case Req.post(embedding_url(),
             headers: [{"Authorization", "Bearer #{api_key}"}],
             json: %{input: texts, model: embedding_model()}
           ) do
        {:ok, %{status: 200, body: %{"data" => data}}} ->
          embeddings = Enum.sort_by(data, & &1["index"]) |> Enum.map(& &1["embedding"])
          {:ok, embeddings}

        {:ok, %{body: body}} ->
          {:error, "embedding API error: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "embedding request failed: #{inspect(reason)}"}
      end
    end
  end

  defp embedding_api_key do
    System.get_env("VOYAGE_API_KEY") ||
      Application.get_env(:james, :anthropic_api_key)
  end

  defp embedding_url do
    System.get_env("EMBEDDING_API_URL", "https://api.voyageai.com/v1/embeddings")
  end

  defp embedding_model do
    System.get_env("EMBEDDING_MODEL", "voyage-3")
  end
end
