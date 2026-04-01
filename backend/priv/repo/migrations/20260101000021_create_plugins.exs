defmodule James.Repo.Migrations.CreatePlugins do
  use Ecto.Migration

  def change do
    create table(:plugins, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :version, :text, default: "0.1.0"
      add :manifest, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :enabled, :boolean, default: true
      timestamps(type: :utc_datetime)
    end

    create index(:plugins, [:user_id])
    create unique_index(:plugins, [:user_id, :name])
  end
end
