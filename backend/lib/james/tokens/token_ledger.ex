defmodule James.Tokens.TokenLedger do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "token_ledger" do
    field :model, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cost_usd, :decimal
    field :inserted_at, :utc_datetime

    belongs_to :session, James.Sessions.Session
    belongs_to :task, James.Tasks.Task
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:session_id, :task_id, :model, :input_tokens, :output_tokens, :cost_usd])
    |> validate_required([:session_id, :model])
  end
end
