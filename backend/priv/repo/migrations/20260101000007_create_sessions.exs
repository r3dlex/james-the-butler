defmodule James.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :host_id, references(:hosts, type: :binary_id, on_delete: :nilify_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
      add :agent_type, :text, default: "chat"
      add :personality_id, references(:personality_profiles, type: :binary_id, on_delete: :nilify_all)
      add :execution_mode, :text
      add :status, :text, default: "active"
      add :keep_intermediates, :boolean, default: false

      timestamps(type: :utc_datetime)
      add :last_used_at, :utc_datetime
    end

    create index(:sessions, [:user_id])
    create index(:sessions, [:status])
  end
end
