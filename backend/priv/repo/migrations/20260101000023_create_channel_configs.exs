defmodule James.Repo.Migrations.CreateChannelConfigs do
  use Ecto.Migration

  def change do
    create table(:channel_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)
      add :mcp_server, :text, null: false
      add :config, :map, default: %{}
      add :sender_rules, :map, default: %{}
      timestamps(type: :utc_datetime)
    end

    create index(:channel_configs, [:user_id])
    create index(:channel_configs, [:session_id])
  end
end
