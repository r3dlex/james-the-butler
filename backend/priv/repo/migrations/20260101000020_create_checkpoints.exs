defmodule James.Repo.Migrations.CreateCheckpoints do
  use Ecto.Migration

  def change do
    create table(:checkpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string
      add :type, :string, default: "implicit", null: false
      add :conversation_snapshot, :map
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:checkpoints, [:session_id])
    create index(:checkpoints, [:type])
  end
end
