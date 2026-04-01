defmodule James.Skills.SkillManageTest do
  use James.DataCase

  alias James.{Skills, Skills.SkillManage}

  describe "handle/2" do
    test "list action returns all skills as formatted text" do
      {:ok, _} = Skills.sync_skill("alpha", "# Alpha\ndef run, do: :alpha")
      {:ok, _} = Skills.sync_skill("beta", "# Beta\ndef run, do: :beta")

      result = SkillManage.handle("list", %{})
      assert is_binary(result)
      assert result =~ "alpha"
      assert result =~ "beta"
    end

    test "list action returns empty message when no skills" do
      result = SkillManage.handle("list", %{})
      assert is_binary(result)
    end

    test "show action returns skill content by name" do
      {:ok, skill} = Skills.sync_skill("show-me", "# ShowMe\ndef run, do: :show")
      result = SkillManage.handle("show", %{"name" => skill.name})
      assert result =~ "ShowMe"
      assert result =~ "show"
    end

    test "show action returns error for unknown skill" do
      result = SkillManage.handle("show", %{"name" => "does-not-exist"})
      assert result =~ "not found"
    end

    test "create action creates a new skill" do
      result =
        SkillManage.handle("create", %{
          "name" => "new-skill",
          "content" => "# NewSkill\ndef run, do: :new"
        })

      assert result =~ "created"
      assert Skills.get_skill_by_name("new-skill") != nil
    end

    test "update action updates an existing skill" do
      {:ok, _} = Skills.sync_skill("update-me", "# V1")

      result =
        SkillManage.handle("update", %{
          "name" => "update-me",
          "content" => "# V2 updated"
        })

      assert result =~ "updated"
      skill = Skills.get_skill_by_name("update-me")
      assert skill.content =~ "V2"
    end

    test "delete action removes a skill" do
      {:ok, _} = Skills.sync_skill("delete-me", "# Bye")
      result = SkillManage.handle("delete", %{"name" => "delete-me"})
      assert result =~ "deleted"
      assert Skills.get_skill_by_name("delete-me") == nil
    end

    test "delete action returns error for unknown skill" do
      result = SkillManage.handle("delete", %{"name" => "ghost"})
      assert result =~ "not found"
    end

    test "unknown action returns error" do
      result = SkillManage.handle("frobnicate", %{})
      assert result =~ "unknown action"
    end
  end
end
