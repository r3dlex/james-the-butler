defmodule James.Sessions.Checkpoint do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "checkpoints" do
    field :name, :string
    field :type, :string, default: "implicit"
    field :conversation_snapshot, :map
    field :metadata, :map, default: %{}

    belongs_to :session, James.Sessions.Session
    timestamps()
  end

  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, [:session_id, :name, :type, :conversation_snapshot, :metadata])
    |> validate_required([:session_id, :type])
    |> validate_inclusion(:type, ~w[implicit explicit])
  end
end
