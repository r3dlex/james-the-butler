defmodule James.Repo.Migrations.CreateArtifacts do
  use Ecto.Migration

  def change do
    create table(:artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :type, :text, null: false
      add :path, :text
      add :is_deliverable, :boolean, default: false

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :cleaned_at, :utc_datetime
    end

    create index(:artifacts, [:session_id])
  end
end
