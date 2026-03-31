defmodule James.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :personality_id, references(:personality_profiles, type: :binary_id, on_delete: :nilify_all)
      add :execution_mode, :text

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])
  end
end
