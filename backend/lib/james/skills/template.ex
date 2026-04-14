defmodule James.Skills.Template do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "skill_templates" do
    field :name, :string
    field :description, :string
    field :content, :string
    field :frontmatter, :map
    belongs_to :skill, James.Skills.Skill

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :description, :content, :frontmatter, :skill_id])
    |> validate_required([:name, :skill_id])
    |> unique_constraint(:skill_id)
  end
end
