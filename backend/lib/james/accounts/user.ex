defmodule James.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :name, :string
    field :email, :string
    field :oauth_provider, :string
    field :oauth_uid, :string
    field :mfa_secret, :string
    field :mfa_method, :string
    field :personality_id, :binary_id
    field :execution_mode, :string, default: "direct"

    has_many :sessions, James.Sessions.Session
    has_many :projects, James.Projects.Project
    has_many :memories, James.Memories.Memory

    belongs_to :personality, James.Accounts.PersonalityProfile,
      foreign_key: :personality_id,
      define_field: false

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email,
      :oauth_provider,
      :oauth_uid,
      :mfa_secret,
      :mfa_method,
      :personality_id,
      :execution_mode
    ])
    |> validate_required([:email])
    |> validate_inclusion(:execution_mode, ["direct", "confirmed"])
    |> validate_inclusion(:mfa_method, ["totp", "webauthn", nil])
    |> unique_constraint(:email)
    |> unique_constraint([:oauth_provider, :oauth_uid])
  end
end
