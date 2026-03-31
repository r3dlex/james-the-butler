defmodule James.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :description, :text
      add :risk_level, :text, default: "read_only"
      add :status, :text, default: "pending"
      add :host_id, references(:hosts, type: :binary_id, on_delete: :nilify_all)

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :completed_at, :utc_datetime
    end

    create index(:tasks, [:session_id, :status])
  end
end
