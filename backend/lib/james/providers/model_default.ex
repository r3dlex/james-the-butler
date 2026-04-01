defmodule James.Providers.ModelDefault do
  @moduledoc """
  Ecto schema for model_defaults — stores per-user, per-host, per-agent-type
  default LLM model configuration.

  Each row identifies which provider config and model name should be used by a
  given agent type when running on a specific host for a specific user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_agent_types ~w(chat code research security desktop browser)

  schema "model_defaults" do
    field :agent_type, :string
    field :model_name, :string

    belongs_to :user, James.Accounts.User
    belongs_to :host, James.Hosts.Host
    belongs_to :provider_config, James.Providers.ProviderConfig

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or upserting a model default.
  """
  def changeset(model_default, attrs) do
    model_default
    |> cast(attrs, [:user_id, :host_id, :agent_type, :provider_config_id, :model_name])
    |> validate_required([:user_id, :host_id, :agent_type, :provider_config_id, :model_name])
    |> validate_inclusion(:agent_type, @valid_agent_types)
    |> unique_constraint(:agent_type,
      name: :model_defaults_user_host_agent_type_index,
      message: "already has a default for this host and agent type"
    )
  end
end
