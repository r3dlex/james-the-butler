# ADR-009: Git identity and repository awareness

## Status

Accepted

## Context

James the Butler operates within user workspaces that may be git repositories. When James makes commits on behalf of a user, those commits should be distinguishable from human commits in `git log`, `git blame`, and GitHub's contributor graph — similar to how tools like GitHub Copilot and Claude Code sign their commits.

Additionally, James should detect when it is operating inside a git repository and expose repository-aware features (branch info, status, diff analysis, commit history).

## Decision

### Git identity for James commits

When James creates commits, it uses a dedicated author identity:

```
Author: James the Butler <james-the-butler[bot]@users.noreply.github.com>
```

This is set via git environment variables or config, **not** by modifying the user's global git config:

```bash
GIT_AUTHOR_NAME="James the Butler"
GIT_AUTHOR_EMAIL="james-the-butler[bot]@users.noreply.github.com"
GIT_COMMITTER_NAME="James the Butler"
GIT_COMMITTER_EMAIL="james-the-butler[bot]@users.noreply.github.com"
```

The `[bot]` suffix in the email follows GitHub's convention for bot accounts, ensuring:
- Commits are visually tagged as bot-authored in GitHub UI
- `git log --author="James"` filters James's commits
- `git blame` clearly attributes automated changes

The **committer** may optionally remain as the human user (only `GIT_AUTHOR_*` is set), preserving the "authored by bot, committed by human" pattern used by GitHub merge commits.

### Repository awareness

When James starts a session in a directory, it checks for a `.git` directory. If found, James:

1. Reads the current branch, status, and recent log
2. Makes git-aware features available (diff analysis, commit, branch management)
3. Respects `.gitignore` when searching files

This detection is automatic — no user configuration required.

## Consequences

- **Positive**: James's changes are traceable and auditable. GitHub UI correctly attributes bot commits. Users can filter or review James's contributions separately.
- **Negative**: Requires consistent use of the identity across all commit paths. Users must understand that James commits are distinguishable but still under their repository's access controls.
