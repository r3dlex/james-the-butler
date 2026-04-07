defmodule James.Repo.Migrations.ChangeMemoriesEmbeddingDimTo384 do
  use Ecto.Migration

  def up do
    alter table(:memories) do
      add :embedding_new, :vector, size: 384
    end

    execute("UPDATE memories SET embedding_new = embedding::vector(384)")

    rename(table(:memories), :embedding, to: :embedding_old)
    rename(table(:memories), :embedding_new, to: :embedding)

    alter table(:memories) do
      remove :embedding_old
    end

    execute("CREATE INDEX memories_embedding_idx ON memories USING hnsw (embedding vector_cosine_ops)")
  end

  def down do
    alter table(:memories) do
      add :embedding_new, :vector, size: 1536
    end

    execute("UPDATE memories SET embedding_new = embedding::vector(1536)")

    rename(table(:memories), :embedding, to: :embedding_old)
    rename(table(:memories), :embedding_new, to: :embedding)

    alter table(:memories) do
      remove :embedding_old
    end

    execute("CREATE INDEX memories_embedding_idx ON memories USING hnsw (embedding vector_cosine_ops)")
  end
end
