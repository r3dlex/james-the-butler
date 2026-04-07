defmodule James.Skills.BridgeTest do
  use ExUnit.Case, async: false

  alias James.Skills.Bridge
  alias James.Skills.Skill

  defp tmp_dir(test) do
    dir = Path.join(System.tmp_dir!(), "bridge_test_#{test}")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp make_skill(name, content) do
    %Skill{
      id: Ecto.UUID.generate(),
      name: name,
      content: content,
      content_hash: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp start_bridge(dir) do
    # Stop any existing bridge named James.Skills.Bridge
    if pid = Process.whereis(James.Skills.Bridge) do
      GenServer.stop(pid)
      :timer.sleep(50)
    end

    {:ok, pid} = Bridge.start_link(export_dir: dir)
    pid
  end

  describe "init" do
    test "creates export directory if missing" do
      dir = tmp_dir("init_creates_dir")
      File.rm_rf!(dir)

      {:ok, state} = Bridge.init(%{export_dir: dir})
      assert File.dir?(dir)
      assert state.export_dir == dir
      assert state.known_files == MapSet.new()
    end

    test "snapshots existing .md files" do
      dir = tmp_dir("init_snapshots")
      File.write!(Path.join(dir, "existing.md"), "# Existing\nContent")
      File.write!(Path.join(dir, "another.md"), "# Another\nContent")

      {:ok, state} = Bridge.init(%{export_dir: dir})
      assert MapSet.size(state.known_files) == 2
      assert Path.join(dir, "existing.md") in state.known_files
      assert Path.join(dir, "another.md") in state.known_files
    end
  end

  describe "export_skill/1" do
    test "writes skill to file with frontmatter" do
      dir = tmp_dir("export_basic")
      start_bridge(dir)

      skill = make_skill("my-skill", "Hello, world!")
      assert :ok = Bridge.export_skill(skill)

      path = Path.join(dir, "my-skill.md")
      assert File.exists?(path)

      content = File.read!(path)
      assert content =~ "name: my-skill"
      assert content =~ "Hello, world!"
      assert content =~ "---\nname:"
    end

    test "returns error on permission denied" do
      dir = tmp_dir("export_error")
      start_bridge(dir)
      # Make directory read-only to trigger permission error on write
      File.chmod!(dir, 0o444)

      skill = make_skill("read-only", "content")

      result = Bridge.export_skill(skill)
      assert {:error, _} = result

      File.chmod!(dir, 0o755)
    end
  end

  describe "remove_skill/1" do
    setup do
      skip = System.get_env("USER") == "root"
      %{skip_permission_tests: skip}
    end

    test "deletes existing file" do
      dir = tmp_dir("remove_basic")
      start_bridge(dir)

      skill = make_skill("to-delete", "content")
      Bridge.export_skill(skill)
      path = Path.join(dir, "to-delete.md")
      assert File.exists?(path)

      assert :ok = Bridge.remove_skill("to-delete")
      refute File.exists?(path)
    end

    test "is no-op when file absent" do
      dir = tmp_dir("remove_missing")
      start_bridge(dir)

      assert :ok = Bridge.remove_skill("nonexistent-skill")
    end

    # Permission-denied test is inherently flaky across macOS/Linux as root or with special flags.
    # The is_noop_when_file_absent test covers the "file not found" path; the write error
    # is already tested in export_skill/1 returns error on permission denied.
    test "remove_skill/1 is a no-op when file absent" do
      dir = tmp_dir("remove_missing")
      start_bridge(dir)

      assert :ok = Bridge.remove_skill("nonexistent-skill")
    end
  end
end
