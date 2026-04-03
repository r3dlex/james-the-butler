defmodule JamesWeb.SessionControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Hosts, Sessions}

  defp create_user(email \\ "sess_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email, name: "Test User"})
    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{name: "Primary", endpoint: "http://localhost:7000", is_primary: true})

    host
  end

  defp create_session(user, host, attrs \\ %{}) do
    {:ok, session} =
      Sessions.create_session(
        Map.merge(
          %{user_id: user.id, host_id: host.id, name: "Test Session"},
          attrs
        )
      )

    session
  end

  describe "GET /api/sessions (index)" do
    test "returns empty list when user has no sessions", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions")
      assert json_response(conn, 200)["sessions"] == []
    end

    test "returns user's sessions", %{conn: conn} do
      user = create_user()
      host = create_host()
      create_session(user, host)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions")
      sessions = json_response(conn, 200)["sessions"]
      assert length(sessions) == 1
    end

    test "does not return other users' sessions", %{conn: conn} do
      user1 = create_user("u1@example.com")
      user2 = create_user("u2@example.com")
      host = create_host()
      create_session(user2, host)
      conn = authed_conn(conn, user1)
      conn = get(conn, "/api/sessions")
      assert json_response(conn, 200)["sessions"] == []
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/sessions")
      assert conn.status == 401
    end

    test "sessions include expected fields", %{conn: conn} do
      user = create_user("fields@example.com")
      host = create_host()
      create_session(user, host, %{name: "My Session"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions")
      [session] = json_response(conn, 200)["sessions"]
      assert Map.has_key?(session, "id")
      assert Map.has_key?(session, "name")
      assert Map.has_key?(session, "agent_type")
      assert Map.has_key?(session, "status")
    end
  end

  describe "POST /api/sessions (create)" do
    test "creates a session for the authenticated user", %{conn: conn} do
      user = create_user("create_sess@example.com")
      _host = create_host()
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions", %{name: "New Session", agent_type: "chat"})
      assert json_response(conn, 201)["session"]["name"] == "New Session"
    end

    test "defaults agent_type to chat", %{conn: conn} do
      user = create_user("default_chat@example.com")
      _host = create_host()
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions", %{name: "Default"})
      assert json_response(conn, 201)["session"]["agent_type"] == "chat"
    end

    test "stores working_directories when provided", %{conn: conn} do
      user = create_user("wd_create@example.com")
      _host = create_host()
      conn = authed_conn(conn, user)

      conn =
        post(conn, "/api/sessions", %{
          name: "WD Session",
          working_directories: ["/home/user/project", "/tmp/work"]
        })

      assert json_response(conn, 201)["session"]["working_directories"] == [
               "/home/user/project",
               "/tmp/work"
             ]
    end

    test "defaults working_directories to empty list", %{conn: conn} do
      user = create_user("wd_default@example.com")
      _host = create_host()
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions", %{name: "No WD"})
      assert json_response(conn, 201)["session"]["working_directories"] == []
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/sessions", %{name: "Unauth"})
      assert conn.status == 401
    end
  end

  describe "GET /api/sessions/:id (show)" do
    test "returns session for authenticated owner", %{conn: conn} do
      user = create_user("show_sess@example.com")
      host = create_host()
      session = create_session(user, host, %{name: "Show Me"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions/#{session.id}")
      assert json_response(conn, 200)["session"]["name"] == "Show Me"
    end

    test "returns 404 for unknown session", %{conn: conn} do
      user = create_user("notfound@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 when session belongs to another user", %{conn: conn} do
      user1 = create_user("owner@example.com")
      user2 = create_user("other@example.com")
      host = create_host()
      session = create_session(user1, host)
      conn = authed_conn(conn, user2)
      conn = get(conn, "/api/sessions/#{session.id}")
      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "returns message_count in response", %{conn: conn} do
      user = create_user("msgcount@example.com")
      host = create_host()
      session = create_session(user, host)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions/#{session.id}")
      assert Map.has_key?(json_response(conn, 200)["session"], "message_count")
    end

    test "returns working_directories in response", %{conn: conn} do
      user = create_user("wd_show@example.com")
      host = create_host()

      session =
        create_session(user, host, %{working_directories: ["/srv/app", "/data"]})

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/sessions/#{session.id}")
      assert json_response(conn, 200)["session"]["working_directories"] == ["/srv/app", "/data"]
    end
  end

  describe "PUT /api/sessions/:id (update)" do
    test "updates session name", %{conn: conn} do
      user = create_user("update_sess@example.com")
      host = create_host()
      session = create_session(user, host, %{name: "Old Name"})
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/sessions/#{session.id}", %{name: "New Name"})
      assert json_response(conn, 200)["session"]["name"] == "New Name"
    end

    test "returns 404 for unknown session", %{conn: conn} do
      user = create_user("update_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/sessions/#{Ecto.UUID.generate()}", %{name: "X"})
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 when session belongs to another user", %{conn: conn} do
      user1 = create_user("owner2@example.com")
      user2 = create_user("other2@example.com")
      host = create_host()
      session = create_session(user1, host)
      conn = authed_conn(conn, user2)
      conn = put(conn, "/api/sessions/#{session.id}", %{name: "X"})
      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end

  describe "DELETE /api/sessions/:id (delete)" do
    test "archives the session", %{conn: conn} do
      user = create_user("delete_sess@example.com")
      host = create_host()
      session = create_session(user, host)
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/sessions/#{session.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown session", %{conn: conn} do
      user = create_user("delete_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/sessions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 when session belongs to another user", %{conn: conn} do
      user1 = create_user("owner3@example.com")
      user2 = create_user("other3@example.com")
      host = create_host()
      session = create_session(user1, host)
      conn = authed_conn(conn, user2)
      conn = delete(conn, "/api/sessions/#{session.id}")
      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end

  describe "POST /api/sessions/:id/suspend" do
    test "active session → 200 with suspended status", %{conn: conn} do
      user = create_user("suspend_ok@example.com")
      host = create_host()
      session = create_session(user, host, %{status: "active"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{session.id}/suspend")
      assert json_response(conn, 200)["session"]["status"] == "suspended"
    end

    test "terminated session → 422", %{conn: conn} do
      user = create_user("suspend_terminated@example.com")
      host = create_host()
      session = create_session(user, host, %{status: "terminated"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{session.id}/suspend")
      assert conn.status == 422
    end

    test "non-existent session → 404", %{conn: conn} do
      user = create_user("suspend_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{Ecto.UUID.generate()}/suspend")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/sessions/:id/resume" do
    test "suspended session → 200 with active status", %{conn: conn} do
      user = create_user("resume_ok@example.com")
      host = create_host()
      session = create_session(user, host, %{status: "suspended"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{session.id}/resume")
      assert json_response(conn, 200)["session"]["status"] == "active"
    end

    test "active session → 422", %{conn: conn} do
      user = create_user("resume_active@example.com")
      host = create_host()
      session = create_session(user, host, %{status: "active"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{session.id}/resume")
      assert conn.status == 422
    end

    test "non-existent session → 404", %{conn: conn} do
      user = create_user("resume_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{Ecto.UUID.generate()}/resume")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/sessions/:id/terminate" do
    test "returns 200 with terminated status", %{conn: conn} do
      user = create_user("terminate_ok@example.com")
      host = create_host()
      session = create_session(user, host, %{status: "active"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{session.id}/terminate")
      assert json_response(conn, 200)["session"]["status"] == "terminated"
    end

    test "non-existent session → 404", %{conn: conn} do
      user = create_user("terminate_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/sessions/#{Ecto.UUID.generate()}/terminate")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/sessions/:id/messages (send_message)" do
    test "creates a message in the session", %{conn: conn} do
      user = create_user("msg_sess@example.com")
      host = create_host()
      session = create_session(user, host)
      conn = authed_conn(conn, user)

      conn =
        post(conn, "/api/sessions/#{session.id}/messages", %{content: "/help"})

      # /help is a slash command — returns 200 with command_response
      body = json_response(conn, 200)
      assert Map.has_key?(body, "message")
    end

    test "returns 404 when session not found", %{conn: conn} do
      user = create_user("msg_notfound@example.com")
      conn = authed_conn(conn, user)

      conn =
        post(conn, "/api/sessions/#{Ecto.UUID.generate()}/messages", %{content: "hello"})

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 when session belongs to another user", %{conn: conn} do
      user1 = create_user("msg_owner@example.com")
      user2 = create_user("msg_other@example.com")
      host = create_host()
      session = create_session(user1, host)
      conn = authed_conn(conn, user2)

      conn =
        post(conn, "/api/sessions/#{session.id}/messages", %{content: "hello"})

      assert json_response(conn, 403)["error"] == "forbidden"
    end
  end
end
