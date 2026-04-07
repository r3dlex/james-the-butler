defmodule James.Skills.Version do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "skill_versions" do
    field :version_number, :integer
    field :content, :string
    field :change_summary, :string
    belongs_to :skill, James.Skills.Skill

    timestamps(type: :utc_datetime)
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:version_number, :content, :change_summary, :skill_id])
    |> validate_required([:version_number, :skill_id, :content])
    |> unique_constraint([:skill_id, :version_number],
      name: :skill_versions_skill_id_version_number_index
    )
  end
end
