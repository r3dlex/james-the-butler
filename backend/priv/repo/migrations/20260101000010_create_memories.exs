defmodule James.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 1536
      add :source_session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:memories, [:user_id])

    execute """
      CREATE INDEX memories_embedding_idx ON memories
      USING hnsw (embedding vector_cosine_ops)
    """, "DROP INDEX IF EXISTS memories_embedding_idx"
  end
end
