# Getting Started

James the Butler is an AI-native agent platform that thinks before it acts, remembers everything, and runs anywhere you work.

## Prerequisites

| Runtime | Minimum version | Used by |
|---------|----------------|---------|
| Elixir | 1.18 | Backend, CLI |
| Erlang/OTP | 27 | Backend, CLI |
| Node.js | 20 | Frontend, Docs |
| Flutter SDK | stable channel | Mobile |
| Python | 3.12+ | Pipeline runner |
| Poetry | latest | Pipeline runner |
| Docker + Compose | latest | Local services |

## Setup

Clone the repository and run the one-command setup:

```bash
git clone https://github.com/andreburgstahler/james-the-butler.git
cd james-the-butler
make setup
```

`make setup` installs dependencies for every component in one shot — backend, frontend, mobile, and the pipeline runner. No global packages are installed beyond the runtimes listed above.

## Start development

```bash
make dev
```

This starts all services (PostgreSQL, Phoenix, Vite dev server) via Docker Compose. Tail logs with `make logs`.

### Start individual services

```bash
make backend-dev    # Phoenix API server on :4000
make frontend-dev   # Vite dev server on :5173
make mobile-dev     # Flutter run (connect a device or emulator)
```

## Run tests

```bash
make test            # All suites
make backend-test    # Elixir/ExUnit only
make frontend-test   # Vitest only
make mobile-test     # Flutter test only
make pipeline-test   # pytest only
```

### With coverage

```bash
make test-coverage
```

## Lint and format

```bash
make lint
```

Runs `mix credo --strict` + `mix format --check-formatted` on the backend, ESLint + Prettier on the frontend, `dart format` + `flutter analyze` on mobile, and `ruff` + `mypy` on the pipeline runner.

## Architecture gate

```bash
make archgate
```

Validates architectural rules (ADR index completeness, component spec presence, no cross-imports, lock files committed, coverage configured). All rules must pass on every PR.

## Documentation site

```bash
make docs-dev        # Browse docs locally at http://localhost:5173
make docs-build      # Build static site to docs/.vitepress/dist/
```

## Quick tour

| What | Where |
|------|-------|
| Platform vision | [spec/platform.md](/spec/platform) |
| Architecture | [spec/architecture.md](/spec/architecture) |
| Backend internals | [spec/elixir.md](/spec/elixir) |
| Frontend internals | [spec/vue.md](/spec/vue) |
| Mobile internals | [spec/flutter.md](/spec/flutter) |
| ADRs | [docs/adr/](/adr/README) |
| Agent guidelines | [AGENTS.md](/agents) |
