defmodule JamesWeb.EmbeddingController do
  use Phoenix.Controller, formats: [:json]

  # POST /api/embeddings
  # Generates an embedding vector for the given text using the configured model.
  def create(conn, %{"text" => text}) do
    case generate_embedding(text) do
      {:ok, embedding} ->
        conn |> json(%{embedding: embedding})
      {:error, reason} ->
        conn |> put_status(:service_unavailable) |> json(%{error: reason})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "text required"})
  end

  defp generate_embedding(text) do
    api_key = Application.get_env(:james, :anthropic_api_key)

    if is_nil(api_key) do
      {:error, "embedding service not configured"}
    else
      response =
        Req.post("https://api.voyageai.com/v1/embeddings",
          headers: [{"Authorization", "Bearer #{api_key}"}],
          json: %{input: [text], model: "voyage-3"}
        )

      case response do
        {:ok, %{status: 200, body: %{"data" => [%{"embedding" => embedding} | _]}}} ->
          {:ok, embedding}

        {:ok, %{body: body}} ->
          {:error, "embedding API error: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "embedding request failed: #{inspect(reason)}"}
      end
    end
  end
end
