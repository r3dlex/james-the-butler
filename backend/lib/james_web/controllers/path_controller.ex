defmodule JamesWeb.PathController do
  use Phoenix.Controller, formats: [:json]

  @doc """
  GET /api/paths/git-check?path=/some/dir
  Returns {is_git: true/false} indicating whether the given path is a git repo.
  """
  def git_check(conn, %{"path" => path}) do
    is_git = File.exists?(Path.join(path, ".git"))
    json(conn, %{is_git: is_git, path: path})
  end

  def git_check(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "path parameter required"})
  end
end
