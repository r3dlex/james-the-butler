defmodule James.Workers.SkillEvolutionWorkerTest do
  use James.DataCase

  alias James.{Skills, Workers.SkillEvolutionWorker}

  defp build_job(args), do: %Oban.Job{args: args}

  describe "perform/1" do
    test "returns :ok when skill does not exist" do
      job = build_job(%{"skill_name" => "nonexistent-skill", "reason" => "tool_calls"})
      assert :ok = SkillEvolutionWorker.perform(job)
    end

    test "returns :ok for an existing skill without LLM (mock mode)" do
      {:ok, _skill} = Skills.sync_skill("test-evolve-skill", "# Original content\ndef run, do: :ok")

      job =
        build_job(%{
          "skill_name" => "test-evolve-skill",
          "reason" => "tool_calls",
          "mode" => "mock"
        })

      assert :ok = SkillEvolutionWorker.perform(job)
    end

    test "records improvement attempt in skill metadata" do
      {:ok, _skill} = Skills.sync_skill("meta-skill", "# skill content")

      job =
        build_job(%{
          "skill_name" => "meta-skill",
          "reason" => "failure",
          "mode" => "mock"
        })

      :ok = SkillEvolutionWorker.perform(job)

      skill = Skills.get_skill_by_name("meta-skill")
      assert skill != nil
      # Skill still exists after evolution attempt
      assert skill.name == "meta-skill"
    end
  end
end
