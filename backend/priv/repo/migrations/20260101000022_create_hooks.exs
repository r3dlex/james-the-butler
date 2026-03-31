defmodule James.Repo.Migrations.CreateHooks do
  use Ecto.Migration

  def change do
    create table(:hooks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :scope, :text, default: "account"
      add :event, :text, null: false
      add :type, :text, null: false
      add :config, :map, default: %{}
      add :matcher, :text
      add :enabled, :boolean, default: true
      timestamps(type: :utc_datetime)
    end

    create index(:hooks, [:user_id])
    create index(:hooks, [:event])
  end
end
