defmodule James.Repo.Migrations.AddSkillTemplatesAndVersions do
  use Ecto.Migration

  def change do
    create table(:skill_templates) do
      add :skill_id, references(:skills, type: :uuid, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :string
      add :content, :text
      add :frontmatter, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:skill_templates, [:skill_id])

    create table(:skill_versions) do
      add :skill_id, references(:skills, type: :uuid, on_delete: :delete_all), null: false
      add :version_number, :integer, null: false
      add :content, :text, null: false
      add :change_summary, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:skill_versions, [:skill_id, :version_number])
  end
end
