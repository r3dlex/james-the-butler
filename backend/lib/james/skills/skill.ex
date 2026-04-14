defmodule James.Skills.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "skills" do
    field :name, :string
    field :content_hash, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:name, :content_hash, :content])
    |> validate_required([:name, :content_hash, :content])
    |> unique_constraint(:name)
  end
end
