defmodule JamesWeb.TaskControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Hosts, Sessions, Tasks}

  defp create_user(email \\ "task_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_host do
    {:ok, host} = Hosts.create_host(%{name: "Task Host", endpoint: "http://localhost:7001"})
    host
  end

  defp create_session(user, host) do
    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Task Session"})

    session
  end

  defp create_task(session, host, attrs \\ %{}) do
    {:ok, task} =
      Tasks.create_task(
        Map.merge(
          %{
            session_id: session.id,
            host_id: host.id,
            description: "Do something",
            risk_level: "read_only",
            status: "pending"
          },
          attrs
        )
      )

    task
  end

  describe "GET /api/tasks (index)" do
    test "returns all tasks", %{conn: conn} do
      user = create_user()
      host = create_host()
      session = create_session(user, host)
      create_task(session, host)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tasks")
      assert json_response(conn, 200)["tasks"] != []
    end

    test "filters by session_id", %{conn: conn} do
      user = create_user("task_filter@example.com")
      host = create_host()
      session = create_session(user, host)
      create_task(session, host, %{description: "Session task"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tasks?session_id=#{session.id}")
      tasks = json_response(conn, 200)["tasks"]
      assert length(tasks) == 1
      assert hd(tasks)["description"] == "Session task"
    end

    test "returns empty list when no tasks", %{conn: conn} do
      user = create_user("task_empty@example.com")
      conn = authed_conn(conn, user)
      # create a fresh unique session_id so no tasks exist for it
      conn = get(conn, "/api/tasks?session_id=#{Ecto.UUID.generate()}")
      assert json_response(conn, 200)["tasks"] == []
    end

    test "tasks include expected fields", %{conn: conn} do
      user = create_user("task_fields@example.com")
      host = create_host()
      session = create_session(user, host)
      create_task(session, host)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tasks?session_id=#{session.id}")
      [task] = json_response(conn, 200)["tasks"]
      assert Map.has_key?(task, "id")
      assert Map.has_key?(task, "description")
      assert Map.has_key?(task, "risk_level")
      assert Map.has_key?(task, "status")
    end
  end

  describe "GET /api/tasks/:id (show)" do
    test "returns task by id", %{conn: conn} do
      user = create_user("task_show@example.com")
      host = create_host()
      session = create_session(user, host)
      task = create_task(session, host, %{description: "Show task"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tasks/#{task.id}")
      assert json_response(conn, 200)["task"]["description"] == "Show task"
    end

    test "returns 404 for unknown task", %{conn: conn} do
      user = create_user("task_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/tasks/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/tasks/:id/approve" do
    test "approves a pending task", %{conn: conn} do
      user = create_user("task_approve@example.com")
      host = create_host()
      session = create_session(user, host)
      task = create_task(session, host, %{status: "pending", risk_level: "destructive"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/tasks/#{task.id}/approve", %{})
      assert json_response(conn, 200)["task"]["status"] == "approved"
    end

    test "returns 404 for unknown task", %{conn: conn} do
      user = create_user("task_approve_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/tasks/#{Ecto.UUID.generate()}/approve", %{})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/tasks/:id/reject" do
    test "rejects a pending task", %{conn: conn} do
      user = create_user("task_reject@example.com")
      host = create_host()
      session = create_session(user, host)
      task = create_task(session, host, %{status: "pending"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/tasks/#{task.id}/reject", %{})
      assert json_response(conn, 200)["task"]["status"] == "rejected"
    end

    test "returns 404 for unknown task", %{conn: conn} do
      user = create_user("task_reject_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/tasks/#{Ecto.UUID.generate()}/reject", %{})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
