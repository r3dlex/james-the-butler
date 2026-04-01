defmodule James.Providers.ProviderConfig do
  @moduledoc """
  Ecto schema for provider_configs — stores per-user LLM provider settings
  including encrypted API keys and OAuth tokens.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_provider_types ~w(
    anthropic
    openai
    openai_codex
    gemini
    minimax
    ollama
    lm_studio
    openai_compatible
  )

  @local_providers ~w(ollama lm_studio openai_compatible)

  @valid_auth_methods ~w(api_key oauth none)
  @valid_statuses ~w(untested connected failed)

  schema "provider_configs" do
    field :provider_type, :string
    field :display_name, :string
    field :api_key_encrypted, :binary
    field :api_key_iv, :binary
    field :base_url, :string
    field :auth_method, :string, default: "api_key"
    field :status, :string, default: "untested"
    field :last_tested_at, :utc_datetime_usec
    field :oauth_token_encrypted, :binary
    field :oauth_refresh_token_encrypted, :binary

    # Virtual field — populated by ProviderSettings after decryption
    field :decrypted_api_key, :string, virtual: true

    belongs_to :user, James.Accounts.User
    belongs_to :host, James.Hosts.Host

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a provider config.

  Validates required fields, allowed enumerations, and that `base_url` is
  present for local providers (ollama, lm_studio, openai_compatible).
  """
  def changeset(config, attrs) do
    config
    |> cast(attrs, [
      :user_id,
      :host_id,
      :provider_type,
      :display_name,
      :api_key_encrypted,
      :api_key_iv,
      :base_url,
      :auth_method,
      :status,
      :last_tested_at,
      :oauth_token_encrypted,
      :oauth_refresh_token_encrypted
    ])
    |> validate_required([:user_id, :provider_type, :display_name])
    |> validate_inclusion(:provider_type, @valid_provider_types)
    |> validate_inclusion(:auth_method, @valid_auth_methods)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_base_url_for_local_providers()
  end

  defp validate_base_url_for_local_providers(changeset) do
    provider_type = get_field(changeset, :provider_type)

    if provider_type in @local_providers do
      validate_required(changeset, [:base_url])
    else
      changeset
    end
  end
end
