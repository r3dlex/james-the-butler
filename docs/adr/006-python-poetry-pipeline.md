# ADR-006: Python/Poetry for pipeline tooling

## Status

Accepted

## Context

We need CI/CD pipeline tooling that can orchestrate builds across all four components, integrate with GitHub Actions, and be easily extended with new pipeline stages.

## Decision

Use **Python 3.12+** with **Poetry** for the pipeline runner tool.

Key technology choices:
- **Poetry** with `pyproject.toml` for dependency management (no setup.py, no requirements.txt)
- **Click** for CLI interface
- **PyGithub** for GitHub API integration
- **Rich** for terminal output formatting
- **pytest** for testing, **ruff** for linting, **mypy** for type checking

The pipeline runner uses a plugin-based stage architecture where each stage (build, test, lint, deploy) is a separate class inheriting from `BaseStage`.

## Consequences

- **Positive**: Python is widely known, making contributions easy. Poetry provides reproducible builds. Click makes CLI development straightforward. Strong GitHub API library support.
- **Negative**: Python is slower than compiled alternatives for pipeline orchestration. Poetry adds a dependency beyond pip. Type checking requires mypy as a separate tool.
