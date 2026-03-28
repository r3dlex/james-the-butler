# James the Butler

A multi-platform butler/assistant application with an Elixir backend, Vue frontend, Flutter mobile client, and Python tooling.

## Quick Start

```bash
make setup    # Install all dependencies (zero-install per component)
make dev      # Start all services in development mode
make test     # Run all test suites
make lint     # Lint all components
```

## Project Layout

| Directory             | Stack           | Purpose                  |
|-----------------------|-----------------|--------------------------|
| `backend/`            | Elixir/Phoenix  | API server & business logic |
| `frontend/`           | Vue 3           | Web UI                   |
| `mobile/`             | Dart/Flutter    | Mobile client            |
| `tools/pipeline_runner/` | Python/Poetry | CI/CD pipeline tooling   |

## Specifications

Component specs live in `spec/` at both the root and within each component directory. Start with `spec/README.md` for the full architecture overview.

## Agent Guidelines

See **[AGENTS.md](AGENTS.md)** for detailed agent instructions, component-specific conventions, and links to each facility's specification.
