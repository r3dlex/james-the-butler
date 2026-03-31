defmodule James.SkillsTest do
  use James.DataCase

  alias James.Skills

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
end
