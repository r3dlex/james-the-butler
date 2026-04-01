defmodule James.Repo.Migrations.CreateTelegramThreads do
  use Ecto.Migration

  def change do
    create table(:telegram_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :telegram_thread_id, :bigint, null: false
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create unique_index(:telegram_threads, [:telegram_thread_id])
  end
end
