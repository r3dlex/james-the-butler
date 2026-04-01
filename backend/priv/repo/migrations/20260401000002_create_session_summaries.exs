defmodule James.Repo.Migrations.CreateSessionSummaries do
  use Ecto.Migration

  def change do
    create table(:session_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :session_id,
          references(:sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :content, :text, null: false

      add :last_message_id,
          references(:messages, type: :binary_id, on_delete: :nilify_all)

      add :token_count_at_extraction, :bigint, null: false, default: 0
      add :tool_calls_at_extraction, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:session_summaries, [:session_id])
    create index(:session_summaries, [:last_message_id])
  end
end
