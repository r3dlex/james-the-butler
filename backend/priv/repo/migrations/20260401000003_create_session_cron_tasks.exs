defmodule James.Repo.Migrations.CreateSessionCronTasks do
  use Ecto.Migration

  def change do
    create table(:session_cron_tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :session_id,
          references(:sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :cron_expression, :string, null: false
      add :prompt, :text, null: false
      add :recurring, :boolean, default: true, null: false
      add :durable, :boolean, default: false, null: false
      add :enabled, :boolean, default: true, null: false
      add :last_fired_at, :utc_datetime_usec
      add :next_fire_at, :utc_datetime_usec, null: false
      add :max_age_days, :integer, default: 30, null: false
      add :expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_cron_tasks, [:session_id])

    create index(:session_cron_tasks, [:next_fire_at],
             where: "enabled = true",
             name: :session_cron_tasks_next_fire_at_enabled_index
           )
  end
end
