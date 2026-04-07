defmodule James.SkillsTest do
  use James.DataCase

  alias James.Skills

  setup do
    # Start the Skills agent for tests (not started in test env by application.ex)
    case Agent.start_link(fn -> %{known_paths: MapSet.new()} end, name: James.Skills) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    on_exit(fn ->
      pid = Process.whereis(James.Skills)
      if pid, do: Process.exit(pid, :kill)
    end)
  end

  defp tmp_dir(ctx) do
    dir = System.tmp_dir!() <> "/skills_test_#{ctx.test}"
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  describe "sync_skill/2" do
    test "creates a new skill when none exists with the given name" do
      assert {:ok, skill} = Skills.sync_skill("my-skill", "def hello, do: :world")
      assert skill.name == "my-skill"
      assert skill.content == "def hello, do: :world"
      assert is_binary(skill.content_hash)
    end

    test "returns existing skill unchanged when content hash matches" do
      {:ok, original} = Skills.sync_skill("stable-skill", "same content")
      assert {:ok, unchanged} = Skills.sync_skill("stable-skill", "same content")
      assert unchanged.id == original.id
      assert unchanged.content_hash == original.content_hash
    end

    test "updates skill when content changes" do
      {:ok, original} = Skills.sync_skill("changing-skill", "version 1")
      assert {:ok, updated} = Skills.sync_skill("changing-skill", "version 2")
      assert updated.id == original.id
      assert updated.content == "version 2"
      assert updated.content_hash != original.content_hash
    end

    test "computes content_hash as SHA256 hex digest" do
      content = "some content"
      expected_hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      {:ok, skill} = Skills.sync_skill("hash-test-skill", content)
      assert skill.content_hash == expected_hash
    end

    test "different skills can coexist" do
      {:ok, _} = Skills.sync_skill("skill-a", "content A")
      {:ok, _} = Skills.sync_skill("skill-b", "content B")
      skills = Skills.list_skills()
      names = Enum.map(skills, & &1.name)
      assert "skill-a" in names
      assert "skill-b" in names
    end
  end

  describe "get_skill/1" do
    test "returns skill by id" do
      {:ok, skill} = Skills.sync_skill("get-skill-test", "content")
      found = Skills.get_skill(skill.id)
      assert found.id == skill.id
    end

    test "returns nil for unknown id" do
      assert Skills.get_skill(Ecto.UUID.generate()) == nil
    end
  end

  describe "delete_skill/1" do
    test "removes the skill" do
      {:ok, skill} = Skills.sync_skill("delete-skill-test", "bye")
      assert {:ok, _} = Skills.delete_skill(skill)
      assert Skills.get_skill(skill.id) == nil
    end
  end

  describe "list_skills/0" do
    test "returns all skills" do
      {:ok, _} = Skills.sync_skill("list-skill-1", "content 1")
      {:ok, _} = Skills.sync_skill("list-skill-2", "content 2")
      skills = Skills.list_skills()
      assert length(skills) >= 2
    end

    test "returns empty list when no skills exist" do
      assert Skills.list_skills() == []
    end

    test "returns skills ordered by name ascending" do
      {:ok, _} = Skills.sync_skill("z-skill", "z")
      {:ok, _} = Skills.sync_skill("a-skill", "a")
      skills = Skills.list_skills()
      names = Enum.map(skills, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "reload_from_dir/1" do
    test "loads skills from temp dir with valid frontmatter", ctx do
      dir = tmp_dir(ctx)

      content = """
      ---
      name: my-skill
      description: A test skill
      tags:
        - test
        - example
      ---
      This is the body content.
      """

      # Strip trailing newline from the heredoc itself
      content = String.trim_trailing(content)
      File.write!(Path.join(dir, "my-skill.md"), content)

      assert :ok = Skills.reload_from_dir(dir)

      skill = Skills.get_skill_by_name("my-skill")
      assert skill != nil
      assert skill.content == "This is the body content."
    end

    test "uses filename as name when no frontmatter name", ctx do
      dir = tmp_dir(ctx)
      File.write!(Path.join(dir, "unnamed-skill.md"), "Raw content here")

      assert :ok = Skills.reload_from_dir(dir)

      skill = Skills.get_skill_by_name("unnamed-skill")
      assert skill != nil
      assert skill.content == "Raw content here"
    end

    test "skips file with malformed frontmatter", ctx do
      dir = tmp_dir(ctx)
      # Missing closing ---
      File.write!(Path.join(dir, "bad-skill.md"), "---\nname: bad\nno closing")

      assert :ok = Skills.reload_from_dir(dir)

      assert Skills.get_skill_by_name("bad-skill") == nil
    end

    test "handles empty directory", ctx do
      dir = tmp_dir(ctx)
      assert :ok = Skills.reload_from_dir(dir)
    end

    test "handles non-existent directory", ctx do
      dir = "/nonexistent/path/to/skills_#{ctx.test}"
      assert :ok = Skills.reload_from_dir(dir)
    end

    test "gracefully handles body containing --- on its own line", ctx do
      dir = tmp_dir(ctx)

      File.write!(Path.join(dir, "code-skill.md"), """
      ---
      name: code-skill
      ---
      # Example Code

      Some code below:

      ---
      def hello do
        :world
      end
      ---
      """)

      assert :ok = Skills.reload_from_dir(dir)

      skill = Skills.get_skill_by_name("code-skill")
      assert skill != nil
      # Body should include the --- separator lines since they weren't treated as frontmatter
      assert "---" in String.split(skill.content, "\n")
    end
  end
end
