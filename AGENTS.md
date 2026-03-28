# Agent Guidelines

This document provides agents with access to each facility in the project. Read the relevant section before working on a component.

## Architecture

Read `spec/README.md` for the high-level architecture and how components interact. Read `spec/architecture.md` for integration details and data flow.

## Facilities

### Backend (Elixir/Phoenix)

- **Location**: `backend/`
- **Spec**: `spec/elixir.md` (system-level), `backend/spec/README.md` (component-level)
- **Language**: Elixir, Phoenix Framework
- **Zero-install**: Run `mix deps.get` — no global tooling beyond Elixir/Erlang required
- **Key commands**: `make backend-setup`, `make backend-test`, `make backend-dev`
- **Conventions**:
  - Follow standard Mix project layout
  - Use contexts for domain boundaries
  - Write ExUnit tests for all public functions
  - Format with `mix format` before committing

### Frontend (Vue 3)

- **Location**: `frontend/`
- **Spec**: `spec/vue.md` (system-level), `frontend/spec/README.md` (component-level)
- **Language**: TypeScript, Vue 3 with Composition API
- **Zero-install**: Run `npm ci` — no global tooling beyond Node.js required
- **Key commands**: `make frontend-setup`, `make frontend-test`, `make frontend-dev`
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
- **Key commands**: `make mobile-setup`, `make mobile-test`, `make mobile-dev`
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
- **Key commands**: `make pipeline-setup`, `make pipeline-test`, `make pipeline-lint`
- **Conventions**:
  - Use `pyproject.toml` for all configuration (no setup.py, setup.cfg, or requirements.txt)
  - Type hints on all public functions
  - pytest for testing, ruff for linting
  - Integrates with GitHub Actions (see `.github/workflows/`)

## Cross-Cutting Concerns

- **Makefile**: The root `Makefile` is the single entry point for all build/test/dev commands
- **CI/CD**: GitHub Actions workflows live in `.github/workflows/`; the pipeline runner orchestrates complex multi-step pipelines
- **Specs**: Every component has a `spec/` directory. Root-level `spec/*.md` files describe system-wide behavior; component-level `spec/README.md` files describe internal design

## Working on Multiple Components

When a change spans components (e.g., adding a new API endpoint consumed by both frontend and mobile):

1. Start with `spec/architecture.md` to understand the integration points
2. Implement backend changes first (API contract)
3. Update frontend and mobile in parallel
4. Run `make test` to verify all components pass
