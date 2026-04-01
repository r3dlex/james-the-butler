defmodule JamesWeb.PersonalityController do
  @moduledoc """
  REST endpoints for personality presets and custom user profiles.

  Presets are built-in read-only configurations. Profiles are custom
  per-user configurations stored in the database.
  """

  use Phoenix.Controller, formats: [:json]

  alias James.{Accounts, Personality}

  @doc "GET /api/personality/presets — returns all built-in presets."
  def presets(conn, _params) do
    conn |> json(%{presets: Enum.map(Personality.presets(), &preset_json/1)})
  end

  @doc "GET /api/personality/profiles — returns the current user's custom profiles."
  def index(conn, _params) do
    user = conn.assigns.current_user
    profiles = Accounts.list_personality_profiles(user)
    conn |> json(%{profiles: Enum.map(profiles, &profile_json/1)})
  end

  @doc "POST /api/personality/profiles — creates a new profile for the current user."
  def create(conn, params) do
    user = conn.assigns.current_user

    attrs = %{
      user_id: user.id,
      name: Map.get(params, "name"),
      preset: Map.get(params, "preset"),
      custom_prompt: Map.get(params, "custom_prompt")
    }

    case Accounts.create_personality_profile(attrs) do
      {:ok, profile} ->
        conn |> put_status(:created) |> json(%{profile: profile_json(profile)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  @doc "PUT /api/personality/profiles/:id — updates a profile owned by the current user."
  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with profile when not is_nil(profile) <- Accounts.get_personality_profile(id),
         true <- profile.user_id == user.id,
         {:ok, updated} <-
           Accounts.update_personality_profile(
             profile,
             Map.take(params, ["name", "preset", "custom_prompt"])
           ) do
      conn |> json(%{profile: profile_json(updated)})
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  @doc "DELETE /api/personality/profiles/:id — deletes a profile owned by the current user."
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with profile when not is_nil(profile) <- Accounts.get_personality_profile(id),
         true <- profile.user_id == user.id,
         {:ok, _} <- Accounts.delete_personality_profile(profile) do
      conn |> json(%{ok: true})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
    end
  end

  defp preset_json(%{id: id, name: name, prompt: prompt}) do
    %{id: id, name: name, prompt: prompt}
  end

  defp profile_json(p) do
    %{
      id: p.id,
      name: p.name,
      preset: p.preset,
      custom_prompt: p.custom_prompt,
      user_id: p.user_id,
      inserted_at: p.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
