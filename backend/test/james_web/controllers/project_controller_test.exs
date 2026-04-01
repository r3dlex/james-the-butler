defmodule JamesWeb.ProjectControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Projects}

  defp create_user(email \\ "proj_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email, name: "Project User"})
    user
  end

  defp create_project(user, attrs \\ %{}) do
    {:ok, project} =
      Projects.create_project(Map.merge(%{user_id: user.id, name: "Test Project"}, attrs))

    project
  end

  describe "GET /api/projects (index)" do
    test "returns empty list when user has no projects", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/projects")
      assert json_response(conn, 200)["projects"] == []
    end

    test "returns user's projects", %{conn: conn} do
      user = create_user()
      create_project(user)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/projects")
      assert length(json_response(conn, 200)["projects"]) == 1
    end

    test "does not return other users' projects", %{conn: conn} do
      user1 = create_user("proj_u1@example.com")
      user2 = create_user("proj_u2@example.com")
      create_project(user2)
      conn = authed_conn(conn, user1)
      conn = get(conn, "/api/projects")
      assert json_response(conn, 200)["projects"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/projects")
      assert conn.status == 401
    end
  end

  describe "POST /api/projects (create)" do
    test "creates a project for authenticated user", %{conn: conn} do
      user = create_user("proj_create@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/projects", %{name: "My Project"})
      assert json_response(conn, 201)["project"]["name"] == "My Project"
    end

    test "returns 422 without name", %{conn: conn} do
      user = create_user("proj_noname@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/projects", %{})
      assert conn.status == 422
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/projects", %{name: "Unauth"})
      assert conn.status == 401
    end

    test "created project has expected fields", %{conn: conn} do
      user = create_user("proj_fields@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/projects", %{name: "Fields Project"})
      project = json_response(conn, 201)["project"]
      assert Map.has_key?(project, "id")
      assert Map.has_key?(project, "name")
      assert Map.has_key?(project, "execution_mode")
    end
  end

  describe "GET /api/projects/:id (show)" do
    test "returns project for owner", %{conn: conn} do
      user = create_user("proj_show@example.com")
      project = create_project(user, %{name: "Show Project"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/projects/#{project.id}")
      assert json_response(conn, 200)["project"]["name"] == "Show Project"
    end

    test "returns 404 for unknown project", %{conn: conn} do
      user = create_user("proj_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/projects/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 when project belongs to another user", %{conn: conn} do
      user1 = create_user("proj_owner@example.com")
      user2 = create_user("proj_other@example.com")
      project = create_project(user1)
      conn = authed_conn(conn, user2)
      conn = get(conn, "/api/projects/#{project.id}")
      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end

  describe "PUT /api/projects/:id (update)" do
    test "updates project name", %{conn: conn} do
      user = create_user("proj_update@example.com")
      project = create_project(user, %{name: "Old Name"})
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/projects/#{project.id}", %{name: "New Name"})
      assert json_response(conn, 200)["project"]["name"] == "New Name"
    end

    test "returns 404 for unknown project", %{conn: conn} do
      user = create_user("proj_upd_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/projects/#{Ecto.UUID.generate()}", %{name: "X"})
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 for other user's project", %{conn: conn} do
      user1 = create_user("proj_upd_owner@example.com")
      user2 = create_user("proj_upd_other@example.com")
      project = create_project(user1)
      conn = authed_conn(conn, user2)
      conn = put(conn, "/api/projects/#{project.id}", %{name: "X"})
      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end

  describe "DELETE /api/projects/:id (delete)" do
    test "deletes project for owner", %{conn: conn} do
      user = create_user("proj_delete@example.com")
      project = create_project(user)
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/projects/#{project.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown project", %{conn: conn} do
      user = create_user("proj_del_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/projects/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 for other user's project", %{conn: conn} do
      user1 = create_user("proj_del_owner@example.com")
      user2 = create_user("proj_del_other@example.com")
      project = create_project(user1)
      conn = authed_conn(conn, user2)
      conn = delete(conn, "/api/projects/#{project.id}")
      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end
end
