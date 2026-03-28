# ADR-002: Zero-install principle

## Status

Accepted

## Context

Developer onboarding friction is a major productivity cost. Each component uses a different language ecosystem, and requiring global tool installations leads to version conflicts and "works on my machine" issues.

## Decision

Every component follows a **zero-install principle**: given only the base runtime (Elixir, Node.js, Flutter SDK, or Python + Poetry), a single setup command installs all dependencies locally with no global side effects.

| Component       | Base Runtime     | Setup Command      |
|-----------------|------------------|--------------------|
| Backend         | Elixir/Erlang    | `mix deps.get`     |
| Frontend        | Node.js          | `npm ci`           |
| Mobile          | Flutter SDK      | `flutter pub get`  |
| Pipeline Runner | Python + Poetry  | `poetry install`   |

The root `Makefile` provides a unified `make setup` that runs all four.

## Consequences

- **Positive**: New contributors can set up any component in one command. No version managers or global package installations needed. CI environments match local development exactly.
- **Negative**: Lock files must be committed for reproducibility. Each ecosystem's package manager has its own quirks to manage.
