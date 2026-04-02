defmodule James.ProviderSettings do
  @moduledoc """
  Context for managing per-user LLM provider configurations.

  Handles CRUD operations and transparently encrypts/decrypts API keys
  and OAuth tokens using `James.Providers.Crypto`.
  """

  import Ecto.Query

  alias James.Accounts.User
  alias James.Providers.Crypto
  alias James.Providers.ModelDefault
  alias James.Providers.ProviderConfig
  alias James.Repo

  @doc """
  Returns all provider configs for the given user.

  API keys are decrypted and placed in the `decrypted_api_key` virtual field.
  """
  @spec list_provider_configs(User.t()) :: [ProviderConfig.t()]
  def list_provider_configs(%User{id: user_id}) do
    ProviderConfig
    |> where([c], c.user_id == ^user_id)
    |> Repo.all()
    |> Enum.map(&decrypt_fields/1)
  end

  @doc """
  Gets a single provider config by ID, returning `nil` if not found.

  The `decrypted_api_key` virtual field is populated on the returned struct.
  """
  @spec get_provider_config(Ecto.UUID.t()) :: ProviderConfig.t() | nil
  def get_provider_config(id) do
    case Repo.get(ProviderConfig, id) do
      nil -> nil
      config -> decrypt_fields(config)
    end
  end

  @doc """
  Gets a single provider config by ID, raising `Ecto.NoResultsError` if not found.

  The `decrypted_api_key` virtual field is populated on the returned struct.
  """
  @spec get_provider_config!(Ecto.UUID.t()) :: ProviderConfig.t()
  def get_provider_config!(id) do
    ProviderConfig
    |> Repo.get!(id)
    |> decrypt_fields()
  end

  @doc """
  Creates a new provider config.

  If `attrs` contains an `:api_key` key, it is encrypted before persisting.
  """
  @spec create_provider_config(map()) :: {:ok, ProviderConfig.t()} | {:error, Ecto.Changeset.t()}
  def create_provider_config(attrs) do
    attrs = encrypt_api_key(attrs)

    %ProviderConfig{}
    |> ProviderConfig.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing provider config.

  If `attrs` contains an `:api_key` key, it is re-encrypted before persisting.
  """
  @spec update_provider_config(ProviderConfig.t(), map()) ::
          {:ok, ProviderConfig.t()} | {:error, Ecto.Changeset.t()}
  def update_provider_config(%ProviderConfig{} = config, attrs) do
    attrs = encrypt_api_key(attrs)

    config
    |> ProviderConfig.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a provider config.
  """
  @spec delete_provider_config(ProviderConfig.t()) ::
          {:ok, ProviderConfig.t()} | {:error, Ecto.Changeset.t()}
  def delete_provider_config(%ProviderConfig{} = config) do
    Repo.delete(config)
  end

  @doc """
  Updates the `status` field and sets `last_tested_at` to the current UTC time.
  """
  @spec update_status(ProviderConfig.t(), String.t()) ::
          {:ok, ProviderConfig.t()} | {:error, Ecto.Changeset.t()}
  def update_status(%ProviderConfig{} = config, status) do
    config
    |> ProviderConfig.changeset(%{
      status: status,
      last_tested_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Model defaults
  # ---------------------------------------------------------------------------

  @doc """
  Creates or updates the default model for a given user/host/agent_type triple.

  On conflict (same `user_id`, `host_id`, `agent_type`), updates `model_name`
  and `provider_config_id`.
  """
  @spec set_default_model(map()) :: {:ok, ModelDefault.t()} | {:error, Ecto.Changeset.t()}
  def set_default_model(attrs) do
    changeset = ModelDefault.changeset(%ModelDefault{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:model_name, :provider_config_id, :updated_at]},
      conflict_target: [:user_id, :host_id, :agent_type],
      returning: true
    )
  end

  @doc """
  Returns `%{model_name: String.t(), provider_config_id: binary()}` for the
  given `user_id`, `host_id`, and `agent_type`, or `nil` if no default is set.
  """
  @spec default_model_for(Ecto.UUID.t(), Ecto.UUID.t(), String.t()) ::
          %{model_name: String.t(), provider_config_id: Ecto.UUID.t()} | nil
  def default_model_for(user_id, host_id, agent_type) do
    result =
      ModelDefault
      |> where(
        [d],
        d.user_id == ^user_id and d.host_id == ^host_id and d.agent_type == ^agent_type
      )
      |> select([d], %{model_name: d.model_name, provider_config_id: d.provider_config_id})
      |> Repo.one()

    result
  end

  @doc """
  Returns all model defaults for the given user.
  """
  @spec list_model_defaults(User.t()) :: [ModelDefault.t()]
  def list_model_defaults(%User{id: user_id}) do
    ModelDefault
    |> where([d], d.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Returns all model defaults for the given user and host.
  """
  @spec list_model_defaults_for_host(Ecto.UUID.t(), Ecto.UUID.t()) :: [ModelDefault.t()]
  def list_model_defaults_for_host(user_id, host_id) do
    ModelDefault
    |> where([d], d.user_id == ^user_id and d.host_id == ^host_id)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Encrypts the plain :api_key from attrs and injects :api_key_encrypted +
  # :api_key_iv into the map, removing the plain key.
  defp encrypt_api_key(attrs) do
    plain_key = Map.get(attrs, :api_key) || Map.get(attrs, "api_key")

    if plain_key do
      case Crypto.encrypt(plain_key) do
        nil ->
          attrs

        {encrypted, iv} ->
          attrs
          |> Map.delete(:api_key)
          |> Map.delete("api_key")
          |> Map.put(:api_key_encrypted, encrypted)
          |> Map.put(:api_key_iv, iv)
      end
    else
      attrs
    end
  end

  # Decrypts api_key_encrypted into the virtual decrypted_api_key field.
  defp decrypt_fields(%ProviderConfig{api_key_encrypted: nil} = config) do
    %{config | decrypted_api_key: nil}
  end

  defp decrypt_fields(%ProviderConfig{api_key_encrypted: enc, api_key_iv: iv} = config)
       when is_binary(enc) and is_binary(iv) do
    case Crypto.decrypt(enc, iv) do
      {:ok, plaintext} -> %{config | decrypted_api_key: plaintext}
      {:error, _} -> %{config | decrypted_api_key: nil}
    end
  end

  defp decrypt_fields(%ProviderConfig{} = config), do: config
end
