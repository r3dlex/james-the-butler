defmodule James.Accounts do
  @moduledoc """
  Manages users and personality profiles.
  """

  import Ecto.Query
  alias James.Accounts.{PersonalityProfile, User}
  alias James.Repo

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_oauth(provider, uid) do
    Repo.get_by(User, oauth_provider: provider, oauth_uid: uid)
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def find_or_create_user_by_oauth(provider, uid, attrs) do
    case get_user_by_oauth(provider, uid) do
      %User{} = user ->
        # Exact provider+uid match — return as-is
        {:ok, user}

      nil ->
        # No provider match; check if an account with the same email already exists
        case attrs[:email] && get_user_by_email(attrs[:email]) do
          %User{} = existing ->
            # Link this provider to the existing email-matched user
            link_oauth_provider(existing, provider, uid)

          _ ->
            # Genuinely new user — create with provider details
            create_user(Map.merge(attrs, %{oauth_provider: provider, oauth_uid: uid}))
        end
    end
  end

  @doc """
  Sets (or updates) the OAuth provider link on an existing user.

  An upsert on the same provider/uid is idempotent.
  """
  def link_oauth_provider(%User{} = user, provider, uid) do
    user
    |> User.changeset(%{oauth_provider: provider, oauth_uid: uid})
    |> Repo.update()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def get_personality_profile(id), do: Repo.get(PersonalityProfile, id)

  def list_personality_profiles(%User{} = user) do
    Repo.all(from p in PersonalityProfile, where: p.user_id == ^user.id)
  end

  def get_personality_profile!(id), do: Repo.get!(PersonalityProfile, id)

  def create_personality_profile(attrs) do
    %PersonalityProfile{}
    |> PersonalityProfile.changeset(attrs)
    |> Repo.insert()
  end

  def update_personality_profile(%PersonalityProfile{} = profile, attrs) do
    profile
    |> PersonalityProfile.changeset(attrs)
    |> Repo.update()
  end

  def delete_personality_profile(%PersonalityProfile{} = profile) do
    Repo.delete(profile)
  end
end
