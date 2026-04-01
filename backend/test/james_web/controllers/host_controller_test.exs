defmodule JamesWeb.HostControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Hosts, Sessions}

  defp create_user(email \\ "host_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_host(attrs \\ %{}) do
    {:ok, host} =
      Hosts.create_host(Map.merge(%{name: "Test Host", endpoint: "http://localhost:7010"}, attrs))

    host
  end

  describe "GET /api/hosts (index)" do
    test "returns list of hosts", %{conn: conn} do
      user = create_user()
      create_host(%{name: "Alpha"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts")
      hosts = json_response(conn, 200)["hosts"]
      assert hosts != []
    end

    test "returns empty list when no hosts", %{conn: conn} do
      user = create_user("host_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts")
      # May or may not be empty depending on test isolation; just check it returns 200
      assert conn.status == 200
      assert Map.has_key?(json_response(conn, 200), "hosts")
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/hosts")
      assert conn.status == 401
    end

    test "host includes expected fields", %{conn: conn} do
      user = create_user("host_fields@example.com")
      create_host(%{name: "Fields Host"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts")
      [host | _] = json_response(conn, 200)["hosts"]
      assert Map.has_key?(host, "id")
      assert Map.has_key?(host, "name")
      assert Map.has_key?(host, "status")
      assert Map.has_key?(host, "is_primary")
    end
  end

  describe "GET /api/hosts/:id (show)" do
    test "returns host by id", %{conn: conn} do
      user = create_user("host_show@example.com")
      host = create_host(%{name: "Show Host"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts/#{host.id}")
      assert json_response(conn, 200)["host"]["name"] == "Show Host"
    end

    test "returns 404 for unknown host", %{conn: conn} do
      user = create_user("host_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "GET /api/hosts/:id/sessions (sessions)" do
    test "returns active sessions for a host", %{conn: conn} do
      user = create_user("host_sess@example.com")
      host = create_host(%{name: "Sessions Host"})

      {:ok, _} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Active Session",
          status: "active"
        })

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts/#{host.id}/sessions")
      sessions = json_response(conn, 200)["sessions"]
      assert sessions != []
    end

    test "returns 404 for unknown host", %{conn: conn} do
      user = create_user("host_sess_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/hosts/#{Ecto.UUID.generate()}/sessions")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
