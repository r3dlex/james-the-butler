defmodule JamesWeb.EmbeddingController do
  use Phoenix.Controller, formats: [:json]

  alias James.Embeddings

  # POST /api/embeddings
  def create(conn, %{"text" => text}) do
    {:ok, embedding} = Embeddings.generate(text)
    conn |> json(%{embedding: embedding})
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "text required"})
  end
end
