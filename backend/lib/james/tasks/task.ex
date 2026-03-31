defmodule James.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tasks" do
    field :description, :string
    field :risk_level, :string, default: "read_only"
    field :status, :string, default: "pending"
    field :inserted_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :session, James.Sessions.Session
    belongs_to :parent_task, James.Tasks.Task, foreign_key: :parent_task_id
    belongs_to :host, James.Hosts.Host

    has_many :sub_tasks, James.Tasks.Task, foreign_key: :parent_task_id
    has_many :artifacts, James.Artifacts.Artifact
    has_many :token_entries, James.Tokens.TokenLedger
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:session_id, :parent_task_id, :description, :risk_level, :status, :host_id, :completed_at])
    |> validate_required([:session_id])
    |> validate_inclusion(:risk_level, ["read_only", "additive", "destructive"])
    |> validate_inclusion(:status, ["pending", "approved", "running", "completed", "rejected", "failed"])
  end
end
