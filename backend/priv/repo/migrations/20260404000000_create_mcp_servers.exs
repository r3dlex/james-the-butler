defmodule James.Repo.Migrations.CreateMcpServers do
  use Ecto.Migration

  def change do
    create table(:mcp_servers, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :transport, :text, null: false
      add :command, :text
      add :url, :text
      add :env, :map, default: %{}
      add :params, :map, default: %{}
      add :tools, :map
      add :status, :text, default: "stopped"

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:mcp_servers, [:user_id])
  end
end
