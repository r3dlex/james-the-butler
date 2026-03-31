defmodule James.Repo.Migrations.CreateMcpConfigs do
  use Ecto.Migration

  def change do
    create table(:mcp_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :transport, :text, null: false
      add :params, :map

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:mcp_configs, [:user_id])
  end
end
