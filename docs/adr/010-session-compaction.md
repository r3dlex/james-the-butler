# ADR-010: Session compaction for context window management

## Status

Accepted

## Context

Long-running sessions accumulate messages that eventually overflow the LLM context
window. Without compaction, the agent either truncates context silently (losing
history) or fails. We need a principled approach to manage context growth.

## Decision

Implement a `James.Compaction` module that:

1. Monitors token usage via `token_ratio/2` against a configurable context limit
2. Fires when the ratio reaches **80%** (`needs_compaction?/2`)
3. Summarises older messages via the configured LLM provider
4. Archives compacted messages into a `Checkpoint` record (conversation_snapshot)
5. Keeps the most recent `keep_last` messages (default 4) active
6. Supports fork-and-continue mode: `fork_session/2` creates a new session
   initialised with the summary as a system message

## Consequences

- **Positive**: Prevents context overflow. Summary checkpoint preserves history.
  Fork-and-continue allows long tasks to continue across compaction boundaries.
- **Negative**: Summarisation loses fine-grained detail. LLM call for summary
  adds latency. Fork sessions break session continuity for the user.

## Implementation Notes

- Compaction is triggered by the chat agent after each assistant response when
  `needs_compaction?` returns true.
- Checkpoint type is `"implicit"` (existing type) with `metadata["compaction"] = true`.
- Summary is stored in `metadata["summary"]`; compacted message count in
  `metadata["message_count"]`.
- Mock mode (`summarize_messages/2` with `mode: :mock`) is used in tests to
  avoid LLM calls.
