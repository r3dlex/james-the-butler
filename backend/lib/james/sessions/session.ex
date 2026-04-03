defmodule James.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :name, :string
    field :agent_type, :string, default: "chat"
    field :execution_mode, :string
    field :status, :string, default: "active"
    field :keep_intermediates, :boolean, default: false
    field :last_used_at, :utc_datetime
    field :working_directories, {:array, :string}, default: []

    belongs_to :user, James.Accounts.User
    belongs_to :host, James.Hosts.Host
    belongs_to :project, James.Projects.Project
    belongs_to :personality, James.Accounts.PersonalityProfile

    has_many :messages, James.Sessions.Message
    has_many :tasks, James.Tasks.Task

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :name,
      :user_id,
      :host_id,
      :project_id,
      :agent_type,
      :personality_id,
      :execution_mode,
      :status,
      :keep_intermediates,
      :working_directories
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:agent_type, ["chat", "code", "research", "desktop", "browser"])
    |> validate_inclusion(:status, ["active", "idle", "archived", "suspended", "terminated"])
    |> validate_inclusion(:execution_mode, ["direct", "confirmed", nil])
  end
end
