# James the Butler — Specification

This directory contains the system-level specifications for the James the Butler project.

## Documents

| File                      | Description                                      |
|---------------------------|--------------------------------------------------|
| [architecture.md](architecture.md) | System architecture, data flow, integration points |
| [elixir.md](elixir.md)   | Backend API server (Elixir/Phoenix)              |
| [vue.md](vue.md)          | Web frontend (Vue 3/TypeScript)                  |
| [flutter.md](flutter.md) | Mobile client (Dart/Flutter)                     |
| [pipeline.md](pipeline.md) | CI/CD pipeline runner (Python/Poetry)          |

## Component-Level Specs

Each component also maintains its own `spec/` directory with internal design details:

- `backend/spec/README.md` — Elixir internals, context boundaries, schema design
- `frontend/spec/README.md` — Vue component tree, store design, routing
- `mobile/spec/README.md` — Flutter widget tree, navigation, platform integration
- `tools/pipeline_runner/spec/README.md` — Pipeline stages, plugin architecture

## Architecture Decision Records

All significant decisions are documented as ADRs in [`docs/adr/`](../docs/adr/README.md). Key decisions include coverage targets ([ADR-007](../docs/adr/007-test-coverage-targets.md)), architecture gate enforcement ([ADR-008](../docs/adr/008-archgate-enforcement.md)), and git identity for James commits ([ADR-009](../docs/adr/009-git-identity-and-repo-awareness.md)).

## How to Read

1. Start with **architecture.md** for the big picture
2. Read the relevant **component spec** (e.g., `elixir.md`) for system-level requirements
3. Dive into the component's own **`spec/README.md`** for implementation details
4. Check **`docs/adr/`** for the rationale behind key decisions
