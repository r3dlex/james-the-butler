defmodule James.Hosts.Host do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "hosts" do
    field :name, :string
    field :endpoint, :string
    field :status, :string, default: "offline"
    field :is_primary, :boolean, default: false
    field :mtls_cert_fingerprint, :string
    field :last_seen_at, :utc_datetime

    field :inserted_at, :utc_datetime
  end

  def changeset(host, attrs) do
    host
    |> cast(attrs, [:name, :endpoint, :status, :is_primary, :mtls_cert_fingerprint, :last_seen_at])
    |> validate_required([:name])
    |> validate_inclusion(:status, ["online", "offline", "draining"])
  end
end
