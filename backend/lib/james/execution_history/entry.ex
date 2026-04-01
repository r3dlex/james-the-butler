defmodule James.ExecutionHistory.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "execution_history" do
    field :structured_log, :map
    field :narrative_summary, :string
    field :inserted_at, :utc_datetime

    belongs_to :session, James.Sessions.Session
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:session_id, :structured_log, :narrative_summary])
    |> validate_required([:session_id])
  end
end
