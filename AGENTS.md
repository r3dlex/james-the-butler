# Agent Guidelines

This document provides agents with access to each facility in the project. Read the relevant section before working on a component.

## Architecture

Read `spec/README.md` for the high-level architecture and how components interact. Read `spec/architecture.md` for integration details and data flow.

## Architecture Decision Records

All significant decisions are documented in `docs/adr/`. See `docs/adr/README.md` for the full index. Before proposing architectural changes, check existing ADRs. New decisions should be recorded as new ADRs.

## Git Identity

When making commits, James uses a dedicated identity to distinguish its commits from human contributors (see [ADR-009](docs/adr/009-git-identity-and-repo-awareness.md)):

```bash
GIT_AUTHOR_NAME="James the Butler"
GIT_AUTHOR_EMAIL="james-the-butler[bot]@users.noreply.github.com"
GIT_COMMITTER_NAME="James the Butler"
GIT_COMMITTER_EMAIL="james-the-butler[bot]@users.noreply.github.com"
```

James should automatically detect when a workspace is a git repository and provide repository-aware features (branch info, status, diff analysis).

## Facilities

### Backend (Elixir/Phoenix)

- **Location**: `backend/`
- **Spec**: `spec/elixir.md` (system-level), `backend/spec/README.md` (component-level)
- **Language**: Elixir, Phoenix Framework
- **Zero-install**: Run `mix deps.get` — no global tooling beyond Elixir/Erlang required
- **Key commands**: `make backend-setup`, `make backend-test`, `make backend-test-coverage`, `make backend-dev`
- **Coverage target**: 80% line coverage (see [ADR-007](docs/adr/007-test-coverage-targets.md))
- **Conventions**:
  - Follow standard Mix project layout
  - Use contexts for domain boundaries
  - All modules must have `@moduledoc` (enforced by `mix credo --strict`)
  - Write ExUnit tests for all public functions
  - Format with `mix format` before committing

### Frontend (Vue 3)

- **Location**: `frontend/`
- **Spec**: `spec/vue.md` (system-level), `frontend/spec/README.md` (component-level)
- **Language**: TypeScript, Vue 3 with Composition API
- **Zero-install**: Run `npm ci` — no global tooling beyond Node.js required
- **Key commands**: `make frontend-setup`, `make frontend-test`, `make frontend-test-coverage`, `make frontend-dev`
- **Coverage target**: 70% line coverage (see [ADR-007](docs/adr/007-test-coverage-targets.md))
- **Conventions**:
  - Use `<script setup lang="ts">` in SFCs
  - Pinia for state management
  - Vitest for unit tests
  - ESLint + Prettier for formatting

### Mobile (Dart/Flutter)

- **Location**: `mobile/`
- **Spec**: `spec/flutter.md` (system-level), `mobile/spec/README.md` (component-level)
- **Language**: Dart, Flutter
- **Zero-install**: Run `flutter pub get` — no global tooling beyond Flutter SDK required
- **Key commands**: `make mobile-setup`, `make mobile-test`, `make mobile-test-coverage`, `make mobile-dev`
- **Coverage target**: 70% line coverage (see [ADR-007](docs/adr/007-test-coverage-targets.md))
- **Conventions**:
  - Follow Flutter/Dart style guide
  - Use Riverpod for state management
  - Write widget tests and unit tests
  - Format with `dart format` before committing

### Pipeline Runner (Python)

- **Location**: `tools/pipeline_runner/`
- **Spec**: `spec/pipeline.md` (system-level), `tools/pipeline_runner/spec/README.md` (component-level)
- **Language**: Python 3.12+, managed with Poetry
- **Zero-install**: Run `poetry install` — no global packages required beyond Poetry itself
- **Key commands**: `make pipeline-setup`, `make pipeline-test`, `make pipeline-test-coverage`, `make pipeline-lint`
- **Coverage target**: 90% line coverage (see [ADR-007](docs/adr/007-test-coverage-targets.md))
- **Conventions**:
  - Use `pyproject.toml` for all configuration (no setup.py, setup.cfg, or requirements.txt)
  - Type hints on all public functions
  - pytest for testing, ruff for linting, mypy for type checking
  - Integrates with GitHub Actions (see `.github/workflows/`)

## Architecture Gate (Archgate)

The pipeline runner includes an `archgate` command that validates architectural rules on every PR (see [ADR-008](docs/adr/008-archgate-enforcement.md)):

```bash
make archgate                              # Run all rules
cd tools/pipeline_runner && poetry run pipeline-runner archgate  # Direct invocation
```

Enforced rules:
- `adr-index` — All ADR files are listed in the index
- `component-spec` — Each component has a `spec/README.md`
- `no-cross-imports` — Components do not import from each other directly
- `lock-files` — Lock files are committed for all components
- `coverage-config` — Coverage thresholds are configured

New rules are added in `tools/pipeline_runner/src/pipeline_runner/stages/archgate.py`.

## Cross-Cutting Concerns

- **Makefile**: The root `Makefile` is the single entry point for all build/test/dev/archgate commands
- **CI/CD**: GitHub Actions workflows live in `.github/workflows/`; the pipeline includes archgate, lint, test, and coverage jobs
- **Specs**: Every component has a `spec/` directory. Root-level `spec/*.md` files describe system-wide behavior; component-level `spec/README.md` files describe internal design
- **ADRs**: Architectural decisions live in `docs/adr/` and are enforced by archgate

## Working on Multiple Components

When a change spans components (e.g., adding a new API endpoint consumed by both frontend and mobile):

1. Start with `spec/architecture.md` to understand the integration points
2. Implement backend changes first (API contract)
3. Update frontend and mobile in parallel
4. Run `make test` to verify all components pass
5. Run `make archgate` to verify architectural constraints
