defmodule James.Plugins.RegistryTest do
  use ExUnit.Case, async: false

  alias James.Plugins.Registry

  setup do
    # Start a fresh Registry if not already started; otherwise just clear it
    case Process.whereis(Registry) do
      nil ->
        {:ok, _pid} = Registry.start_link([])

      _pid ->
        # Clear all entries between tests
        all = Registry.list_all()
        Enum.each(Map.keys(all), &Registry.unregister/1)
    end

    :ok
  end

  describe "register/2 and get/1" do
    test "registers a manifest and retrieves it" do
      manifest = %{"name" => "my-plugin", "version" => "1.0.0"}
      Registry.register("plugin-1", manifest)
      assert Registry.get("plugin-1") == manifest
    end

    test "returns nil for an unregistered plugin" do
      assert Registry.get("no-such-plugin") == nil
    end

    test "overwrites an existing registration" do
      Registry.register("plugin-2", %{"v" => 1})
      Registry.register("plugin-2", %{"v" => 2})
      assert Registry.get("plugin-2")["v"] == 2
    end
  end

  describe "unregister/1" do
    test "removes a registered plugin" do
      Registry.register("plugin-rm", %{"x" => 1})
      Registry.unregister("plugin-rm")
      assert Registry.get("plugin-rm") == nil
    end

    test "is a no-op for an unknown plugin" do
      # Should not raise
      assert :ok = Registry.unregister("ghost-plugin")
    end
  end

  describe "list_all/0" do
    test "returns an empty map when nothing is registered" do
      assert Registry.list_all() == %{}
    end

    test "returns all registered manifests" do
      Registry.register("p-a", %{"name" => "a"})
      Registry.register("p-b", %{"name" => "b"})
      all = Registry.list_all()
      assert Map.has_key?(all, "p-a")
      assert Map.has_key?(all, "p-b")
    end

    test "does not include unregistered plugins" do
      Registry.register("p-c", %{"name" => "c"})
      Registry.unregister("p-c")
      refute Map.has_key?(Registry.list_all(), "p-c")
    end
  end

  describe "skills_for_plugin/1" do
    test "returns an empty list for a plugin without skills" do
      Registry.register("no-skills", %{"name" => "bare"})
      assert Registry.skills_for_plugin("no-skills") == []
    end

    test "returns the skills list when present in the manifest" do
      skills = ["skill_a", "skill_b"]
      Registry.register("with-skills", %{"skills" => skills})
      assert Registry.skills_for_plugin("with-skills") == skills
    end

    test "returns an empty list for an unregistered plugin" do
      assert Registry.skills_for_plugin("never-registered") == []
    end
  end
end
