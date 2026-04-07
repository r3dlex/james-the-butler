defmodule James.Plugins.Plugin do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "plugins" do
    field :name, :string
    field :version, :string, default: "0.1.0"
    field :manifest, :map, default: %{}
    field :enabled, :boolean, default: true
    field :code_path, :string
    field :permissions, :map, default: %{}
    field :installed_at, :utc_datetime
    field :last_active_at, :utc_datetime

    belongs_to :user, James.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [
      :name,
      :version,
      :manifest,
      :user_id,
      :enabled,
      :code_path,
      :permissions,
      :installed_at,
      :last_active_at
    ])
    |> validate_required([:name, :user_id])
    |> unique_constraint([:user_id, :name])
  end
end
