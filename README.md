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

| Directory                | Stack           | Purpose                    |
|--------------------------|-----------------|----------------------------|
| `backend/`               | Elixir/Phoenix  | API server & business logic|
| `frontend/`              | Vue 3           | Web UI                     |
| `mobile/`                | Dart/Flutter    | Mobile client              |
| `tools/pipeline_runner/` | Python/Poetry   | CI/CD pipeline tooling     |

## Specifications

Component specs live in `spec/` at both the root and within each component directory. Start with [`spec/README.md`](spec/README.md) for the full architecture overview.

## Development

Each component follows a **zero-install** principle — given the base runtime, running the setup command installs everything locally:

```bash
make backend-setup     # mix deps.get && mix compile
make frontend-setup    # npm ci
make mobile-setup      # flutter pub get
make pipeline-setup    # poetry install
```

## License

[MIT](LICENSE)
