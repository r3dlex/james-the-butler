defmodule James.Projects do
  @moduledoc """
  Manages projects.
  """

  import Ecto.Query
  alias James.Projects.Project
  alias James.Repo

  def list_projects(user_id) do
    Repo.all(from p in Project, where: p.user_id == ^user_id, order_by: [desc: p.inserted_at])
  end

  def get_project(id), do: Repo.get(Project, id)

  def get_project!(id), do: Repo.get!(Project, id)

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end
end
