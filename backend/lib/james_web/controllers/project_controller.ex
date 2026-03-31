defmodule JamesWeb.ProjectController do
  use Phoenix.Controller, formats: [:json]

  alias James.Projects

  def index(conn, _params) do
    user = conn.assigns.current_user
    projects = Projects.list_projects(user.id)
    conn |> json(%{projects: Enum.map(projects, &project_json/1)})
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    attrs = %{
      user_id: user.id,
      name: Map.get(params, "name"),
      personality_id: Map.get(params, "personality_id"),
      execution_mode: Map.get(params, "execution_mode")
    }

    case Projects.create_project(attrs) do
      {:ok, project} ->
        conn |> put_status(:created) |> json(%{project: project_json(project)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Projects.get_project(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      p when p.user_id != user.id -> conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
      project -> conn |> json(%{project: project_json(project)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with project when not is_nil(project) <- Projects.get_project(id),
         true <- project.user_id == user.id,
         {:ok, updated} <- Projects.update_project(project, Map.take(params, ["name", "personality_id", "execution_mode"])) do
      conn |> json(%{project: project_json(updated)})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with project when not is_nil(project) <- Projects.get_project(id),
         true <- project.user_id == user.id,
         {:ok, _} <- Projects.delete_project(project) do
      conn |> json(%{ok: true})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
    end
  end

  defp project_json(p) do
    %{id: p.id, name: p.name, execution_mode: p.execution_mode, personality_id: p.personality_id, inserted_at: p.inserted_at}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
