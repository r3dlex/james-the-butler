defmodule James.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field :name, :string
    field :execution_mode, :string

    belongs_to :user, James.Accounts.User
    belongs_to :personality, James.Accounts.PersonalityProfile

    has_many :sessions, James.Sessions.Session

    timestamps(type: :utc_datetime)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :user_id, :personality_id, :execution_mode])
    |> validate_required([:name, :user_id])
    |> validate_inclusion(:execution_mode, ["direct", "confirmed", nil])
  end
end
