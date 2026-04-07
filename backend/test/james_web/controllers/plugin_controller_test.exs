defmodule JamesWeb.PluginControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Plugins}

  defp create_user(email \\ "plugin_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp install_plugin(user, attrs \\ %{}) do
    attrs =
      for {k, v} <-
            Map.merge(%{"user_id" => user.id, "name" => "my-plugin", "version" => "1.0.0"}, attrs),
          into: %{},
          do: {to_string(k), v}

    {:ok, plugin} = Plugins.install_plugin(attrs)
    plugin
  end

  describe "GET /api/plugins (index)" do
    test "returns user's plugins", %{conn: conn} do
      user = create_user()
      install_plugin(user, %{name: "plugin-alpha"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/plugins")
      plugins = json_response(conn, 200)["plugins"]
      assert plugins != []
    end

    test "returns empty list when user has no plugins", %{conn: conn} do
      user = create_user("plugin_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/plugins")
      assert json_response(conn, 200)["plugins"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/plugins")
      assert conn.status == 401
    end
  end

  describe "POST /api/plugins (install)" do
    test "installs a plugin for authenticated user", %{conn: conn} do
      user = create_user("plugin_install@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/plugins", %{name: "new-plugin", version: "0.1.0"})
      assert json_response(conn, 201)["plugin"]["name"] == "new-plugin"
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/plugins", %{name: "unauth-plugin"})
      assert conn.status == 401
    end
  end

  describe "DELETE /api/plugins/:id (uninstall)" do
    test "uninstalls a plugin", %{conn: conn} do
      user = create_user("plugin_delete@example.com")
      plugin = install_plugin(user, %{name: "to-delete"})
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/plugins/#{plugin.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown plugin", %{conn: conn} do
      user = create_user("plugin_del_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/plugins/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/plugins/:id/enable" do
    test "enables a disabled plugin", %{conn: conn} do
      user = create_user("plugin_enable@example.com")
      plugin = install_plugin(user, %{name: "enable-me"})
      {:ok, plugin} = Plugins.disable_plugin(plugin)
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/plugins/#{plugin.id}/enable", %{})
      assert json_response(conn, 200)["plugin"]["enabled"] == true
    end

    test "returns 404 for unknown plugin", %{conn: conn} do
      user = create_user("plugin_enable_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/plugins/#{Ecto.UUID.generate()}/enable", %{})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  describe "POST /api/plugins/:id/disable" do
    test "disables an enabled plugin", %{conn: conn} do
      user = create_user("plugin_disable@example.com")
      plugin = install_plugin(user, %{name: "disable-me"})
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/plugins/#{plugin.id}/disable", %{})
      assert json_response(conn, 200)["plugin"]["enabled"] == false
    end

    test "returns 404 for unknown plugin", %{conn: conn} do
      user = create_user("plugin_disable_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/plugins/#{Ecto.UUID.generate()}/disable", %{})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
