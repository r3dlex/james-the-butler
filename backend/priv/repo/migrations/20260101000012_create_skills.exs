defmodule James.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :content_hash, :text, null: false
      add :content, :text, null: false
      add :scope, :text, default: "global"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:skills, [:content_hash])
  end
end
