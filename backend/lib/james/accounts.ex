defmodule James.Accounts do
  @moduledoc """
  Manages users and personality profiles.
  """

  import Ecto.Query
  alias James.Repo
  alias James.Accounts.{User, PersonalityProfile}

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
      nil ->
        create_user(Map.merge(attrs, %{oauth_provider: provider, oauth_uid: uid}))
      user ->
        {:ok, user}
    end
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

  def create_personality_profile(attrs) do
    %PersonalityProfile{}
    |> PersonalityProfile.changeset(attrs)
    |> Repo.insert()
  end
end
