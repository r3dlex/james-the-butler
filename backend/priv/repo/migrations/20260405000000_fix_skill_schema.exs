defmodule James.Repo.Migrations.FixSkillSchema do
  use Ecto.Migration

  def change do
    drop index(:skills, [:content_hash])

    alter table(:skills, primary_key: false) do
      remove :scope
    end

    create unique_index(:skills, [:name])
  end
end
