defmodule James.MCP.Server do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_servers" do
    field :name, :string
    field :transport, :string
    field :command, :string
    field :url, :string
    field :env, :map, default: %{}
    field :params, :map, default: %{}
    field :tools, {:array, :map}
    field :status, :string, default: "stopped"

    belongs_to :user, James.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :transport, :command, :url, :env, :params, :user_id, :status])
    |> validate_required([:name, :transport, :user_id])
    |> validate_inclusion(:transport, ["stdio", "sse", "streamable_http"])
    |> unique_constraint([:user_id, :name])
  end
end
