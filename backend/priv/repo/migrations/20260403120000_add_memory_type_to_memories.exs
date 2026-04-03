defmodule James.Repo.Migrations.AddMemoryTypeToMemories do
  use Ecto.Migration

  def change do
    alter table(:memories) do
      add :memory_type, :string, default: "general"
    end

    execute """
    ALTER TABLE memories ADD CONSTRAINT memory_type_check CHECK (memory_type IN ('general', 'codebase_fact', 'user_preference', 'session_summary', 'codebase_navigation'))
    """, """
    ALTER TABLE memories DROP CONSTRAINT memory_type_check
    """

    create index(:memories, [:user_id, :memory_type])
  end
end
