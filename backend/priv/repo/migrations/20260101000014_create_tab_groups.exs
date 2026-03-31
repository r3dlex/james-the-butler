defmodule James.Repo.Migrations.CreateTabGroups do
  use Ecto.Migration

  def change do
    create table(:tab_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :chrome_group_id, :integer
      add :color, :text
      add :tabs, {:array, :map}

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :last_active_at, :utc_datetime
    end

    create index(:tab_groups, [:session_id])
  end
end
