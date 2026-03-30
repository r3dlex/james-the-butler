---
name: dream
description: "Cleanse and consolidate memory, connections, and unnecessary files — like sleep does for the human brain"
user_invocable: true
command: dream
---

# Dream Mode

You are entering Dream Mode — a maintenance cycle that cleanses, consolidates, and optimizes the agent's working state, much like sleep consolidates memory and clears metabolic waste in the human brain.

## Phase 1: Memory Audit

1. Read the MEMORY.md index file at the project memory path
2. For each memory file referenced in MEMORY.md:
   - Read the memory file
   - Check if the memory is still accurate by verifying against current project state (files, git history, etc.)
   - Classify as: **keep** (still valid and useful), **update** (valid concept but details changed), **remove** (stale, duplicate, or no longer relevant)
3. For memories classified as "update": rewrite them with current accurate information
4. For memories classified as "remove": delete the memory file and remove its entry from MEMORY.md
5. Check for duplicate or overlapping memories and merge them
6. Report what was kept, updated, merged, and removed

## Phase 2: Connection Check

1. Scan for any MCP server configurations, API connections, or integration references in:
   - `.claude/` directory
   - Project configuration files
   - Environment files (check for stale `.env` references without exposing values)
2. For each connection found, verify it is still referenced/needed by the codebase
3. Report any orphaned connections or stale integration references (do NOT delete these — just report)

## Phase 3: Workspace Cleanup

1. Check for temporary or unnecessary files:
   - Orphaned plan files in `.claude/plans/`
   - Stale todo lists in `.claude/todos/`
   - Build artifacts that shouldn't be committed (check `.gitignore` coverage)
   - Empty directories
   - Duplicate files (same content, different names)
2. Check git status for any untracked files that may be accidental
3. Report findings but ask before deleting anything

## Phase 4: Project Health Scan

1. Run a quick health check:
   - Are all dependencies up to date? (`mix.lock`, `package-lock.json`, `pubspec.lock`, `poetry.lock`)
   - Are there any TODO/FIXME/HACK comments that reference completed work?
   - Is the README still accurate?
   - Do all spec files reference current project structure?
2. Summarize project health as a brief "dream journal" entry

## Phase 5: Dream Journal

After completing all phases, produce a concise **Dream Journal** summary:

```
--- Dream Journal ---
Date: [current date]
Duration: [time taken]

Memories:
  Kept: N | Updated: N | Merged: N | Removed: N

Connections:
  Active: N | Orphaned: N

Workspace:
  Files cleaned: N | Issues found: N

Health:
  [One-line health summary]

Dream complete. Ready for a new day.
---
```

## Important Rules

- NEVER delete memory files without showing the user what will be removed and getting confirmation
- NEVER expose secrets, tokens, or credentials — just note their existence
- NEVER modify source code — this is a maintenance/hygiene operation only
- Be thorough but fast — dream mode should feel like a quick refresh, not a deep audit
- If the memory directory is empty, note it and skip Phase 1
- If no issues are found, say so — a clean dream is a good dream
