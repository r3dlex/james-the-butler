defmodule James.PluginsTest do
  use James.DataCase

  alias James.{Accounts, Plugins}

  defp create_user(email \\ "plugin_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp install(user, attrs \\ %{}) do
    {:ok, plugin} =
      Plugins.install_plugin(Map.merge(%{user_id: user.id, name: "my-plugin"}, attrs))

    plugin
  end

  describe "install_plugin/1" do
    test "installs a plugin for a user" do
      user = create_user()
      assert {:ok, plugin} = Plugins.install_plugin(%{user_id: user.id, name: "awesome-plugin"})
      assert plugin.user_id == user.id
      assert plugin.name == "awesome-plugin"
    end

    test "defaults enabled to true" do
      user = create_user("plugin_enabled@example.com")
      {:ok, plugin} = Plugins.install_plugin(%{user_id: user.id, name: "auto-enabled"})
      assert plugin.enabled == true
    end

    test "defaults version to 0.1.0" do
      user = create_user("plugin_version@example.com")
      {:ok, plugin} = Plugins.install_plugin(%{user_id: user.id, name: "versioned"})
      assert plugin.version == "0.1.0"
    end

    test "fails when user_id is missing" do
      assert {:error, changeset} = Plugins.install_plugin(%{name: "orphan"})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when name is missing" do
      user = create_user("plugin_no_name@example.com")
      assert {:error, changeset} = Plugins.install_plugin(%{user_id: user.id})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails on duplicate user+name" do
      user = create_user("plugin_dup@example.com")
      {:ok, _} = Plugins.install_plugin(%{user_id: user.id, name: "duplicate"})
      assert {:error, changeset} = Plugins.install_plugin(%{user_id: user.id, name: "duplicate"})
      assert %{} = errors_on(changeset)
    end
  end

  describe "list_plugins/1" do
    test "returns plugins for user" do
      user = create_user("list_plugins@example.com")
      install(user, %{name: "plugin-a"})
      install(user, %{name: "plugin-b"})
      plugins = Plugins.list_plugins(user.id)
      assert length(plugins) == 2
    end

    test "does not return other users' plugins" do
      user1 = create_user("plug_u1@example.com")
      user2 = create_user("plug_u2@example.com")
      install(user1, %{name: "u1-plugin"})
      assert Plugins.list_plugins(user2.id) == []
    end

    test "returns empty list when no plugins" do
      user = create_user("no_plugins@example.com")
      assert Plugins.list_plugins(user.id) == []
    end
  end

  describe "enable_plugin/1" do
    test "sets plugin enabled to true" do
      user = create_user("enable_plugin@example.com")
      plugin = install(user)
      {:ok, _disabled} = Plugins.disable_plugin(plugin)
      refreshed = Plugins.get_plugin(plugin.id)
      assert {:ok, enabled} = Plugins.enable_plugin(refreshed)
      assert enabled.enabled == true
    end
  end

  describe "disable_plugin/1" do
    test "sets plugin enabled to false" do
      user = create_user("disable_plugin@example.com")
      plugin = install(user)
      assert {:ok, disabled} = Plugins.disable_plugin(plugin)
      assert disabled.enabled == false
    end
  end

  describe "uninstall_plugin/1" do
    test "removes the plugin" do
      user = create_user("uninstall_plugin@example.com")
      plugin = install(user)
      assert {:ok, _} = Plugins.uninstall_plugin(plugin)
      assert Plugins.get_plugin(plugin.id) == nil
    end
  end
end
