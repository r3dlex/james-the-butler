defmodule James.Skills do
  @moduledoc "Manages skill definitions stored in the database."

  import Ecto.Query
  alias James.Repo
  alias James.Skills.Skill

  def list_skills do
    from(s in Skill, order_by: [asc: s.name])
    |> Repo.all()
  end

  def get_skill(id), do: Repo.get(Skill, id)

  def get_skill_by_name(name) do
    Repo.get_by(Skill, name: name)
  end

  def create_skill(attrs) do
    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
  end

  def update_skill(%Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end

  def delete_skill(%Skill{} = skill) do
    Repo.delete(skill)
  end

  @doc "Sync a skill from filesystem content. Creates or updates based on content_hash."
  def sync_skill(name, content) do
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

    case get_skill_by_name(name) do
      nil ->
        create_skill(%{name: name, content: content, content_hash: hash})

      %{content_hash: ^hash} = skill ->
        {:ok, skill}

      skill ->
        update_skill(skill, %{content: content, content_hash: hash})
    end
  end
end
