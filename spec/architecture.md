# Architecture

## Overview

James the Butler is a multi-platform assistant application. The system follows a client-server architecture with a single backend serving multiple clients.

```
┌─────────────┐     ┌─────────────┐
│  Vue Web UI │     │ Flutter App │
└──────┬──────┘     └──────┬──────┘
       │                   │
       └────────┬──────────┘
                │  HTTPS / WebSocket
        ┌───────▼────────┐
        │ Phoenix Backend │
        │  (JSON API +    │
        │   Channels)     │
        └───────┬─────────┘
                │
        ┌───────▼────────┐
        │   PostgreSQL    │
        └────────────────┘

┌──────────────────────────┐
│  Pipeline Runner (Python)│──▶ GitHub Actions
└──────────────────────────┘
```

## Component Responsibilities

### Backend (Elixir/Phoenix)
- REST API and WebSocket channels for real-time updates
- Authentication and authorization
- Business logic via Phoenix contexts
- Database access (Ecto + PostgreSQL)

### Frontend (Vue 3)
- Web-based UI consuming the backend API
- Real-time updates via Phoenix channels (WebSocket)
- Responsive design for desktop and tablet

### Mobile (Dart/Flutter)
- Native mobile experience on iOS and Android
- Consumes the same backend API as the web frontend
- Offline-first where feasible, syncing when connectivity is restored

### Pipeline Runner (Python)
- Orchestrates CI/CD pipelines
- Integrates with GitHub Actions as both a trigger and a step
- Provides reusable pipeline stages (build, test, deploy)

## Data Flow

1. **Client → Backend**: Clients send HTTP requests or connect via WebSocket
2. **Backend → Database**: Ecto queries against PostgreSQL
3. **Backend → Clients**: JSON responses or channel broadcasts
4. **Pipeline Runner → GitHub Actions**: Triggers workflows and collects results

## Integration Points

| Producer        | Consumer         | Protocol         | Contract               |
|-----------------|------------------|------------------|------------------------|
| Backend         | Frontend         | REST + WebSocket | OpenAPI spec (planned) |
| Backend         | Mobile           | REST + WebSocket | Same OpenAPI spec      |
| Pipeline Runner | GitHub Actions   | GitHub API       | Workflow YAML          |

## Environment Requirements

All components follow a **zero-install** principle: given the base runtime (Elixir, Node.js, Flutter SDK, Python + Poetry), running the component's setup command installs everything locally with no global side effects.
