defmodule James.Repo.Migrations.CreateExecutionHistory do
  use Ecto.Migration

  def change do
    create table(:execution_history, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :structured_log, :map
      add :narrative_summary, :text

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:execution_history, [:session_id])
  end
end
