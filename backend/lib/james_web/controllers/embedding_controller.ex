defmodule JamesWeb.EmbeddingController do
  use Phoenix.Controller, formats: [:json]

  alias James.Embeddings

  # POST /api/embeddings
  def create(conn, %{"text" => text}) do
    case Embeddings.generate(text) do
      {:ok, embedding} ->
        conn |> json(%{embedding: embedding})

      {:error, reason} ->
        conn |> put_status(:service_unavailable) |> json(%{error: reason})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "text required"})
  end
end
