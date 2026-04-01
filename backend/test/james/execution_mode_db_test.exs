defmodule James.ExecutionModeDbTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Projects, Sessions}
  alias James.ExecutionMode

  defp create_user(attrs \\ %{}) do
    {:ok, user} =
      Accounts.create_user(
        Map.merge(%{email: "emd_#{System.unique_integer()}@example.com"}, attrs)
      )

    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "emd-host-#{System.unique_integer()}",
        endpoint: "http://localhost"
      })

    host
  end

  describe "resolve/1 — project-level fallback" do
    test "returns project execution_mode when session has none" do
      user = create_user()
      host = create_host()

      {:ok, project} =
        Projects.create_project(%{
          user_id: user.id,
          name: "proj-#{System.unique_integer()}",
          execution_mode: "confirmed"
        })

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Test",
          project_id: project.id
        })

      assert ExecutionMode.resolve(session) == "confirmed"
    end

    test "falls to user mode when project has no execution_mode" do
      user = create_user()
      {:ok, user} = Accounts.update_user(user, %{execution_mode: "direct"})
      host = create_host()

      {:ok, project} =
        Projects.create_project(%{user_id: user.id, name: "proj-#{System.unique_integer()}"})

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Test",
          project_id: project.id
        })

      assert ExecutionMode.resolve(session) == "direct"
    end

    test "falls to 'direct' when project and user both have no mode" do
      user = create_user()
      host = create_host()

      {:ok, project} =
        Projects.create_project(%{user_id: user.id, name: "proj-#{System.unique_integer()}"})

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Test",
          project_id: project.id
        })

      assert ExecutionMode.resolve(session) == "direct"
    end
  end

  describe "resolve/1 — user-level fallback" do
    test "returns user execution_mode when session has none" do
      user = create_user()
      {:ok, user} = Accounts.update_user(user, %{execution_mode: "confirmed"})
      host = create_host()

      {:ok, session} =
        Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Test"})

      assert ExecutionMode.resolve(session) == "confirmed"
    end

    test "falls to 'direct' when user has no execution_mode" do
      user = create_user()
      host = create_host()

      {:ok, session} =
        Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Test"})

      assert ExecutionMode.resolve(session) == "direct"
    end
  end
end
