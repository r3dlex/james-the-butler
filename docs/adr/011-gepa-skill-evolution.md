# ADR-011: GEPA-style skill evolution

## Status

Accepted

## Context

Skills are reusable instruction blocks stored in the database. Over time, skills
that work poorly in practice should improve automatically. We need a mechanism to
detect underperforming skills and evolve them without manual intervention.

## Decision

Implement GEPA (Guided Evolutionary Prompt Architecture) style skill improvement:

1. **`James.Skills.ImprovementTrigger`** evaluates execution context heuristics:
   - `tool_call_count >= 5` → skill is inefficient
   - `retry_count >= 2` → skill is fragile
   - `failure_count >= 1` → skill has a bug or design flaw

2. **`James.Workers.SkillEvolutionWorker`** (Oban, `skills` queue) receives the
   skill name and trigger reason, then:
   - Builds an improvement prompt including the original skill content and reason
   - Calls the configured LLM provider's `send_message/2`
   - Syncs the improved version via `Skills.sync_skill/2` (content-hash versioning
     — no-op if the LLM returns identical content)

3. **`James.Skills.SkillManage`** provides the `skill_manage` tool interface for
   agents to list, show, create, update, and delete skills.

## Consequences

- **Positive**: Skills improve automatically based on real usage patterns.
  Content-hash versioning ensures idempotence. Mock mode enables testability.
- **Negative**: LLM-generated improvements may degrade quality. Oban retries
  capped at 2 to avoid excessive LLM spend. Improvement quality depends on
  prompt engineering.

## Implementation Notes

- The `skills` Oban queue runs with concurrency 2 to prevent excessive LLM spend.
- `ImprovementTrigger.score/1` enables future prioritisation of evolution jobs.
- Skills use SHA-256 content hashing — identical content never creates duplicate
  DB records.
