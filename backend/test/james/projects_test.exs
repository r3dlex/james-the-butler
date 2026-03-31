defmodule James.ProjectsTest do
  use James.DataCase

  alias James.{Accounts, Projects}

  defp create_user(email \\ "proj_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_project(user, attrs \\ %{}) do
    {:ok, project} =
      Projects.create_project(Map.merge(%{user_id: user.id, name: "My Project"}, attrs))

    project
  end

  describe "create_project/1" do
    test "creates a project with user_id and name" do
      user = create_user()
      assert {:ok, project} = Projects.create_project(%{user_id: user.id, name: "Alpha"})
      assert project.user_id == user.id
      assert project.name == "Alpha"
    end

    test "fails when user_id is missing" do
      assert {:error, changeset} = Projects.create_project(%{name: "Orphan"})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when name is missing" do
      user = create_user("proj_no_name@example.com")
      assert {:error, changeset} = Projects.create_project(%{user_id: user.id})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid execution_mode" do
      user = create_user("proj_bad_mode@example.com")

      assert {:error, changeset} =
               Projects.create_project(%{
                 user_id: user.id,
                 name: "Bad Mode",
                 execution_mode: "turbo"
               })

      assert %{execution_mode: [_]} = errors_on(changeset)
    end
  end

  describe "list_projects/1" do
    test "lists projects for user" do
      user = create_user("list_proj@example.com")
      create_project(user, %{name: "Alpha"})
      create_project(user, %{name: "Beta"})
      projects = Projects.list_projects(user.id)
      assert length(projects) == 2
    end

    test "does not return other users' projects" do
      user1 = create_user("proj_u1@example.com")
      user2 = create_user("proj_u2@example.com")
      create_project(user1)
      assert Projects.list_projects(user2.id) == []
    end

    test "returns empty list when user has no projects" do
      user = create_user("no_proj@example.com")
      assert Projects.list_projects(user.id) == []
    end
  end

  describe "get_project/1" do
    test "returns project by id" do
      user = create_user("get_proj@example.com")
      project = create_project(user)
      assert found = Projects.get_project(project.id)
      assert found.id == project.id
    end

    test "returns nil for unknown id" do
      assert Projects.get_project(Ecto.UUID.generate()) == nil
    end
  end

  describe "update_project/2" do
    test "updates the project name" do
      user = create_user("update_proj@example.com")
      project = create_project(user, %{name: "Old"})
      assert {:ok, updated} = Projects.update_project(project, %{name: "New"})
      assert updated.name == "New"
    end

    test "updates the execution_mode" do
      user = create_user("proj_mode@example.com")
      project = create_project(user)
      assert {:ok, updated} = Projects.update_project(project, %{execution_mode: "confirmed"})
      assert updated.execution_mode == "confirmed"
    end
  end

  describe "delete_project/1" do
    test "removes the project" do
      user = create_user("delete_proj@example.com")
      project = create_project(user)
      assert {:ok, _} = Projects.delete_project(project)
      assert Projects.get_project(project.id) == nil
    end
  end
end
