defmodule JamesWeb.SkillController do
  use Phoenix.Controller, formats: [:json]

  alias James.Skills

  def index(conn, _params) do
    skills = Skills.list_skills()
    json(conn, %{skills: Enum.map(skills, &skill_json/1)})
  end

  def create(conn, params) do
    case Skills.create_skill(params) do
      {:ok, skill} ->
        conn |> put_status(:created) |> json(%{skill: skill_json(skill)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Skills.get_skill(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      skill ->
        case Skills.update_skill(skill, params) do
          {:ok, updated} ->
            json(conn, %{skill: skill_json(updated)})

          {:error, changeset} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Skills.get_skill(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      skill ->
        {:ok, _} = Skills.delete_skill(skill)
        json(conn, %{ok: true})
    end
  end

  defp skill_json(s) do
    %{
      id: s.id,
      name: s.name,
      scope: s.scope,
      content_hash: s.content_hash,
      inserted_at: s.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.into(%{})
  end
end
