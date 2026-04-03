defmodule James.Sessions.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :role, :string
    field :content, :string
    field :token_count, :integer
    field :model, :string
    field :inserted_at, :utc_datetime_usec

    belongs_to :session, James.Sessions.Session
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:session_id, :role, :content, :token_count, :model])
    |> validate_required([:session_id, :role])
    |> validate_inclusion(:role, ["user", "assistant", "system", "planner"])
  end
end
