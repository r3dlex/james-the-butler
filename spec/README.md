# James the Butler — Specification

> These specifications are also published as a Vitepress documentation site. Run `make docs-dev` to browse them locally.

This directory contains the system-level specifications for the James the Butler platform.

## Start Here

| File | Description |
|---|---|
| [platform.md](platform.md) | **Full platform specification v1.5** — vision, architecture, all subsystems (all 7 phases implemented) |
| [architecture.md](architecture.md) | System architecture, data flow, integration points |

## Component Specs

| File | Description |
|---|---|
| [elixir.md](elixir.md) | Backend — Phoenix, OpenClaw, meta-planner, Oban, Telegram bot |
| [vue.md](vue.md) | Frontend — Vue 3, Tauri desktop, VitePress docs |
| [flutter.md](flutter.md) | Mobile — Flutter, WebRTC live stream, QR host binding |
| [pipeline.md](pipeline.md) | Pipeline runner — CI/CD orchestration (Python/Poetry) |

## Integration Specs

| File | Description |
|---|---|
| [office-addins.md](office-addins.md) | Office Add-ins — Word, Excel, PowerPoint (Office.js) |
| [chrome-extension.md](chrome-extension.md) | Chrome Extension — CDP browser sidebar (Manifest V3) |
| [security.md](security.md) | Security model — OAuth, MFA, JWT, mTLS, device code flow |
| [api.md](api.md) | API endpoint reference — REST + WebSocket channels |
| [database.md](database.md) | Database schema reference — PostgreSQL + pgvector |
| [webrtc.md](webrtc.md) | WebRTC streaming — live desktop/browser video to clients |

## Component-Level Specs

Each component maintains its own `spec/` directory with internal design details:

- `backend/spec/README.md` — Contexts, schema, GenServer design, OpenClaw internals
- `frontend/spec/README.md` — Vue component tree, store design, routing, Tauri integration
- `mobile/spec/README.md` — Widget tree, navigation, WebRTC, host binding
- `tools/pipeline_runner/spec/README.md` — Pipeline stages, archgate rules, plugin architecture

## Architecture Decision Records

All significant decisions are documented as ADRs in [`docs/adr/`](../docs/adr/README.md). Key decisions include coverage targets ([ADR-007](../docs/adr/007-test-coverage-targets.md)), architecture gate enforcement ([ADR-008](../docs/adr/008-archgate-enforcement.md)), and git identity ([ADR-009](../docs/adr/009-git-identity-and-repo-awareness.md)).

## How to Read

1. Start with **[platform.md](platform.md)** for the full platform vision and requirements
2. Read **[architecture.md](architecture.md)** for technical integration details
3. Read the relevant **component spec** (e.g., `elixir.md`) for system-level requirements
4. Dive into the component's own **`spec/README.md`** for implementation details
5. Check **`docs/adr/`** for the rationale behind key decisions
