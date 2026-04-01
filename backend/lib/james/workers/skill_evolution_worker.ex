defmodule James.Workers.SkillEvolutionWorker do
  @moduledoc """
  Oban worker that attempts to evolve a skill using GEPA-style improvement.

  Triggered by `ImprovementTrigger` when a session exhibits heuristics that
  suggest a skill needs refinement (excessive tool use, retries, or failures).

  ## Job Args

  - `"skill_name"` — name of the skill to evolve
  - `"reason"` — trigger reason atom as string: `"tool_calls"`, `"retries"`, `"failure"`
  - `"mode"` — optional: `"mock"` for test/dev mode (default: uses LLM)
  - `"session_context"` — optional map with execution context for the LLM prompt

  ## Evolution Strategy

  1. Load the current skill content
  2. Build an improvement prompt using the trigger reason and session context
  3. Request an improved version from the LLM (or return mock in test mode)
  4. Sync the improved skill back via `Skills.sync_skill/2` (content-hash versioning)
     — if the LLM returns identical content the skill is unchanged (no-op)
  """

  use Oban.Worker, queue: :skills, max_attempts: 2

  require Logger

  alias James.Skills

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    skill_name = args["skill_name"]
    reason = args["reason"]
    mode = args["mode"] || "llm"
    session_context = args["session_context"] || %{}

    Logger.info("SkillEvolutionWorker: evolving '#{skill_name}' (reason: #{reason})")

    case Skills.get_skill_by_name(skill_name) do
      nil ->
        Logger.warning("SkillEvolutionWorker: skill '#{skill_name}' not found, skipping")
        :ok

      skill ->
        evolve(skill, reason, mode, session_context)
    end
  end

  defp evolve(skill, reason, "mock", _ctx) do
    # In mock/test mode, append a comment to signal evolution without an LLM call
    evolved_content = skill.content <> "\n# evolved: #{reason} at #{DateTime.utc_now()}"

    case Skills.sync_skill(skill.name, evolved_content) do
      {:ok, _updated} ->
        Logger.info("SkillEvolutionWorker: mock evolution complete for '#{skill.name}'")
        :ok

      {:error, err} ->
        Logger.error("SkillEvolutionWorker: failed to sync evolved skill: #{inspect(err)}")
        {:error, err}
    end
  end

  defp evolve(skill, reason, _llm_mode, ctx) do
    prompt = build_prompt(skill.content, reason, ctx)
    provider = James.LLMProvider.configured()

    case provider.send_message([%{role: "user", content: prompt}]) do
      {:ok, %{content: improved_content}} ->
        sync_evolved(skill, improved_content)

      {:error, llm_reason} ->
        Logger.error("SkillEvolutionWorker: LLM call failed: #{inspect(llm_reason)}")
        :ok
    end
  end

  defp sync_evolved(skill, improved_content) do
    case Skills.sync_skill(skill.name, improved_content) do
      {:ok, _updated} ->
        Logger.info("SkillEvolutionWorker: evolved skill '#{skill.name}'")
        :ok

      {:error, err} ->
        Logger.error("SkillEvolutionWorker: sync failed: #{inspect(err)}")
        {:error, err}
    end
  end

  defp build_prompt(content, reason, ctx) do
    context_info =
      if map_size(ctx) > 0 do
        "\n\nExecution context:\n#{Jason.encode!(ctx, pretty: true)}"
      else
        ""
      end

    reason_desc =
      case reason do
        "tool_calls" -> "The skill required too many tool calls (5+), suggesting redundancy."
        "retries" -> "The skill required multiple retries, suggesting fragility."
        "failure" -> "The skill produced failures, suggesting a bug or design flaw."
        other -> "Improvement trigger: #{other}."
      end

    """
    You are a skill improvement assistant. A skill is a reusable instruction block for an AI agent.

    #{reason_desc}#{context_info}

    Current skill content:
    ```
    #{content}
    ```

    Please provide an improved version of this skill that addresses the identified issue.
    Return ONLY the improved skill content, no explanation.
    """
  end
end
