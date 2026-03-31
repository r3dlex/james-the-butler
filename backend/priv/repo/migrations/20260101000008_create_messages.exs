defmodule James.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :text, null: false
      add :content, :text
      add :token_count, :integer
      add :model, :text

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:messages, [:session_id])
  end
end
