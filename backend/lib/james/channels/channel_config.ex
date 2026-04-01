defmodule James.Channels.ChannelConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "channel_configs" do
    field :mcp_server, :string
    field :config, :map, default: %{}
    field :sender_rules, :map, default: %{}

    belongs_to :user, James.Accounts.User
    belongs_to :session, James.Sessions.Session
    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:user_id, :session_id, :mcp_server, :config, :sender_rules])
    |> validate_required([:user_id, :mcp_server])
  end
end
