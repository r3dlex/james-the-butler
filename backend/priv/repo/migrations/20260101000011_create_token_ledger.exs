defmodule James.Repo.Migrations.CreateTokenLedger do
  use Ecto.Migration

  def change do
    create table(:token_ledger, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :model, :text, null: false
      add :input_tokens, :integer, default: 0
      add :output_tokens, :integer, default: 0
      add :cost_usd, :decimal, precision: 10, scale: 6

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:token_ledger, [:session_id])
  end
end
