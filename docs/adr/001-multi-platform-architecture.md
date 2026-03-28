# ADR-001: Multi-platform architecture

## Status

Accepted

## Context

James the Butler needs to serve users across web browsers and mobile devices. We need to decide whether to build a single cross-platform UI, separate native clients, or a hybrid approach.

## Decision

We adopt a shared-backend, multi-client architecture:

- A single **Elixir/Phoenix backend** serves all clients via REST and WebSocket APIs.
- A **Vue 3 web frontend** provides the browser experience.
- A **Flutter mobile app** provides native iOS and Android clients.
- A **Python pipeline runner** handles CI/CD orchestration.

Each client is an independent project with its own build, test, and deploy lifecycle. They share only the API contract.

## Consequences

- **Positive**: Each client can use the best tools for its platform. Backend changes are deployed once and serve all clients. Teams can work independently on each client.
- **Negative**: API contract changes require coordination. Feature parity across clients requires discipline. More CI/CD complexity with four separate build pipelines.
