defmodule James.Skills.WatcherTest do
  use ExUnit.Case, async: false

  alias James.Skills.Watcher

  @poll_interval 100

  defp tmp_dir do
    dir = System.tmp_dir!() |> Path.join("watcher_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp start_watcher(dir, opts \\ []) do
    base_opts = [dir: dir, poll_interval: @poll_interval]
    {:ok, pid} = Watcher.start_link(Keyword.merge(base_opts, opts))
    pid
  end

  describe "start_link/1" do
    test "GenServer starts successfully with a configured directory" do
      dir = tmp_dir()
      pid = start_watcher(dir)
      assert Process.alive?(pid)
    after
      :ok
    end

    test "starts successfully even when directory does not exist (no crash)" do
      missing = "/tmp/watcher_no_such_dir_#{System.unique_integer([:positive])}"
      pid = start_watcher(missing)
      assert Process.alive?(pid)
    end
  end

  describe "check_for_changes/1" do
    test "detects new .md files in the skills directory" do
      dir = tmp_dir()
      pid = start_watcher(dir)

      # Confirm baseline shows no changes
      assert :unchanged = Watcher.check_for_changes(pid)

      # Write a new skill file
      File.write!(Path.join(dir, "new_skill.md"), "# New Skill")

      assert {:changed, paths} = Watcher.check_for_changes(pid)
      assert Enum.any?(paths, &String.ends_with?(&1, "new_skill.md"))
    end

    test "detects modified files (mtime changed)" do
      dir = tmp_dir()
      path = Path.join(dir, "existing.md")
      File.write!(path, "original content")

      pid = start_watcher(dir)

      # Consume the initial state so next check starts fresh
      Watcher.check_for_changes(pid)

      # Modify file — bump mtime by at least 1 second
      :timer.sleep(1_100)
      File.write!(path, "updated content")

      assert {:changed, paths} = Watcher.check_for_changes(pid)
      assert path in paths
    end

    test "ignores non-.md files" do
      dir = tmp_dir()
      pid = start_watcher(dir)

      # Baseline
      Watcher.check_for_changes(pid)

      # Write a non-.md file
      File.write!(Path.join(dir, "notes.txt"), "just a text file")

      assert :unchanged = Watcher.check_for_changes(pid)
    end

    test "returns list of changed file paths" do
      dir = tmp_dir()
      pid = start_watcher(dir)
      Watcher.check_for_changes(pid)

      File.write!(Path.join(dir, "skill_a.md"), "Skill A")
      File.write!(Path.join(dir, "skill_b.md"), "Skill B")

      assert {:changed, paths} = Watcher.check_for_changes(pid)
      assert is_list(paths)
      assert length(paths) >= 2
    end

    test "handles missing directory gracefully (no crash)" do
      missing = "/tmp/watcher_gone_#{System.unique_integer([:positive])}"
      pid = start_watcher(missing)
      assert :unchanged = Watcher.check_for_changes(pid)
      assert Process.alive?(pid)
    end
  end

  describe "debounce" do
    test "multiple rapid changes result in single reload callback" do
      dir = tmp_dir()
      parent = self()

      on_change = fn -> send(parent, :reloaded) end

      pid = start_watcher(dir, on_change: on_change)

      # Write multiple files rapidly
      for i <- 1..5 do
        File.write!(Path.join(dir, "skill_#{i}.md"), "content #{i}")
      end

      # Trigger polling by waiting slightly more than poll_interval + debounce
      :timer.sleep(@poll_interval + 400)

      # Should have received only one :reloaded message
      count =
        Enum.reduce_while(1..10, 0, fn _, acc ->
          receive do
            :reloaded -> {:cont, acc + 1}
          after
            0 -> {:halt, acc}
          end
        end)

      assert count == 1
      assert Process.alive?(pid)
    end
  end
end
