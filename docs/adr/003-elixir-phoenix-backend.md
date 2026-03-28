# ADR-003: Elixir/Phoenix for backend

## Status

Accepted

## Context

The backend must handle concurrent WebSocket connections for real-time features, REST API endpoints, and background job processing. We need a technology that excels at concurrency and fault tolerance.

## Decision

Use **Elixir 1.16+** with **Phoenix 1.7+** as the backend framework, backed by **PostgreSQL** via **Ecto**.

Key technology choices:
- **Phoenix Channels** for real-time WebSocket communication
- **Ecto** with PostgreSQL for data persistence
- **Phoenix Contexts** for domain boundary organization
- **Bandit** as the HTTP server (Phoenix 1.7+ default)
- **Credo** for static analysis (`--strict` mode in CI)
- **ExUnit** for testing with `Ecto.Adapters.SQL.Sandbox` for test isolation

## Consequences

- **Positive**: BEAM VM provides excellent concurrency and fault tolerance. Phoenix Channels give first-class WebSocket support. Pattern matching and immutability reduce bugs. Hot code reloading in development.
- **Negative**: Smaller ecosystem than Node.js or Python. Fewer developers familiar with Elixir. Deployment requires BEAM VM on production servers.
