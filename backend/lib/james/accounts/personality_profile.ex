defmodule James.Accounts.PersonalityProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "personality_profiles" do
    field :name, :string
    field :preset, :string
    field :custom_prompt, :string

    belongs_to :user, James.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :user_id, :preset, :custom_prompt])
    |> validate_required([:name, :user_id])
  end
end
