# Architecture

For the full platform specification, see [platform.md](platform.md).

## Overview

James the Butler is an AI-native agent platform with a multi-host, planner-first architecture. A single Elixir/Phoenix backend serves web, desktop (Tauri), mobile (Flutter), Office add-in, and Telegram clients.

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Vue Web/    │  │ Flutter App  │  │ Office.js    │  │  Telegram    │
│  Tauri Desk  │  │ (iOS/Android)│  │ Add-ins      │  │  Bot         │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                  │
       └─────────┬───────┴─────────┬───────┘                 │
                 │  HTTPS / WS     │                          │
         ┌───────▼─────────────────▼──────────────────────────▼───┐
         │              Phoenix Backend (Primary Host)            │
         │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
         │  │ Meta-Planner │  │   OpenClaw   │  │ Telegram Bot │ │
         │  │  (GenServer)  │  │ (GenServer)  │  │  (Phoenix)   │ │
         │  └──────┬───────┘  └──────┬───────┘  └──────────────┘ │
         │         │                 │                            │
         │  ┌──────▼─────────────────▼──────┐                    │
         │  │   Agent Sub-Sessions          │                    │
         │  │   (Supervised GenServers)     │                    │
         │  └───────────────────────────────┘                    │
         │                                                        │
         │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
         │  │  PostgreSQL  │  │   pgvector   │  │     Oban     │ │
         │  │  (Ecto)      │  │  (memories)  │  │   (jobs)     │ │
         │  └──────────────┘  └──────────────┘  └──────────────┘ │
         └────────────────────────┬───────────────────────────────┘
                                  │ mTLS
         ┌────────────────────────▼───────────────────────────────┐
         │              Worker Host(s)                            │
         │  ┌──────────────┐  ┌──────────────┐                   │
         │  │   OpenClaw   │  │ Agent Workers│                   │
         │  │ (GenServer)  │  │ (GenServers) │                   │
         │  └──────────────┘  └──────────────┘                   │
         └────────────────────────────────────────────────────────┘

┌──────────────────────────────┐
│  Pipeline Runner (Python)    │──▶ GitHub Actions
└──────────────────────────────┘
```

## Component Responsibilities

### Backend (Elixir/Phoenix) — `james-server`
- REST API and WebSocket channels (Phoenix Channels) for all clients
- Meta-planner: task decomposition, risk tagging, host routing
- OpenClaw: local session lifecycle, agent worker supervision, CDP Chrome management, desktop control daemon
- Telegram bot: thread-to-session routing, voice transcription (Whisper)
- Memory: extraction via Oban jobs, vector storage via pgvector, semantic retrieval
- Embeddings: `/embeddings` endpoint for all clients (web, mobile, Office, Chrome extension)
- Auth: OAuth 2.0 (Google/Microsoft/GitHub), MFA (TOTP/WebAuthn), JWT with refresh rotation
- Token ledger: per-session cost tracking, budget alerts
- Tab group state persistence for browser control sessions

### Frontend (Vue 3) — `james-app`
- Web UI and Tauri desktop app (same codebase)
- Session management, project dashboards, memory review
- Real-time streaming via Phoenix socket client
- VitePress documentation site

### Mobile (Flutter) — `james-mobile`
- Remote viewer and controller (no local agents)
- QR code host binding with secure enclave storage
- WebRTC live stream for desktop and browser control sessions
- Multi-host switching

### Office Add-ins (Office.js) — `james-office`
- Word, Excel, PowerPoint integration (shared repo)
- Progressive document retrieval (chunk → embed → semantic search)
- Device code auth, session picker, structured diff view

### Chrome Extension — `james-chrome`
- Manifest V3 extension for CDP-controlled Chrome instance
- Session sidebar: conversation, tab groups, task status, token cost, execution mode toggle
- Device code auth (same mechanism as Office add-ins)
- WebSocket + REST communication with james-server

### Pipeline Runner (Python) — `tools/pipeline_runner`
- CI/CD orchestration for all components
- Architecture gate enforcement (archgate)
- GitHub Actions integration

## Data Flow

1. **Client → Meta-Planner**: All input routes through the planner first
2. **Meta-Planner → OpenClaw**: Tasks dispatched to target host's OpenClaw
3. **OpenClaw → Agent Workers**: Sub-sessions run as supervised GenServers
4. **Agent → Backend**: Results stored in PostgreSQL, streamed to clients via Channels
5. **Memory Extraction**: Oban background jobs process conversation deltas into pgvector
6. **Memory Retrieval**: Semantic search on session start and per-message

## Multi-Host Communication

| Producer | Consumer | Protocol | Purpose |
|---|---|---|---|
| Primary Meta-Planner | Worker OpenClaw | mTLS | Task dispatch |
| Worker OpenClaw | Primary | mTLS | Status/results |
| Backend | All clients | HTTPS + WS | API + streaming |
| Mobile | Backend | WebRTC | Computer use live stream |
| Pipeline Runner | GitHub Actions | GitHub API | CI/CD |

## Environment Requirements

All components follow a **zero-install** principle (see [ADR-002](../docs/adr/002-zero-install-principle.md)). Given the base runtime, running the component's setup command installs everything locally with no global side effects.
