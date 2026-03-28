# James the Butler

An AI-native agent platform with Elixir/Phoenix backend, Vue 3 frontend (web + Tauri desktop), Flutter mobile client, and Python CI/CD tooling. See `spec/platform.md` for the full platform specification.

## Quick Start

```bash
make setup    # Install all dependencies (zero-install per component)
make dev      # Start all services in development mode
make test     # Run all test suites
make lint     # Lint all components
make archgate # Run architecture gate checks
```

## Project Layout

| Directory                | Stack           | Purpose                              |
|--------------------------|-----------------|--------------------------------------|
| `backend/`               | Elixir/Phoenix  | API server, OpenClaw, meta-planner   |
| `frontend/`              | Vue 3 / Tauri   | Web UI and desktop app               |
| `mobile/`                | Dart/Flutter    | Mobile remote viewer and controller  |
| `tools/pipeline_runner/` | Python/Poetry   | CI/CD pipeline and archgate          |

## Specifications

Start with **[spec/platform.md](spec/platform.md)** for the full platform vision. Component specs live in `spec/` at both the root and within each component directory. See `spec/README.md` for the reading order.

## Architecture Decision Records

Significant decisions are documented in **[docs/adr/](docs/adr/README.md)**.

## Agent Guidelines

See **[AGENTS.md](AGENTS.md)** for detailed agent instructions, component-specific conventions, and links to each facility's specification.
