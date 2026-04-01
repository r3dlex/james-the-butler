defmodule James.SessionSummaries.SessionSummary do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "session_summaries" do
    field :content, :string
    field :token_count_at_extraction, :integer, default: 0
    field :tool_calls_at_extraction, :integer, default: 0

    belongs_to :session, James.Sessions.Session
    belongs_to :last_message, James.Sessions.Message, foreign_key: :last_message_id

    timestamps(type: :utc_datetime)
  end

  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :session_id,
      :content,
      :last_message_id,
      :token_count_at_extraction,
      :tool_calls_at_extraction
    ])
    |> validate_required([:session_id, :content])
    |> unique_constraint(:session_id)
  end
end
