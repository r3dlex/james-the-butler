defmodule James.Memories.Memory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "memories" do
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector
    field :memory_type, :string, default: "general"
    field :inserted_at, :utc_datetime

    belongs_to :user, James.Accounts.User
    belongs_to :source_session, James.Sessions.Session, foreign_key: :source_session_id
  end

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:user_id, :content, :embedding, :source_session_id, :memory_type])
    |> validate_required([:user_id, :content])
    |> validate_inclusion(:memory_type, ~w(general codebase_fact user_preference session_summary codebase_navigation))
  end
end
