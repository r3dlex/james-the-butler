<p align="center">
  <img src="assets/logo/logo.svg" alt="James the Butler" width="80" height="80">
</p>

<h1 align="center">James the Butler</h1>

<p align="center">
  <strong>Your AI-native agent platform — plan, act, remember, everywhere.</strong>
</p>

<p align="center">
  <a href="https://github.com/andreburgstahler/james-the-butler/actions"><img alt="CI" src="https://github.com/andreburgstahler/james-the-butler/actions/workflows/pipeline.yml/badge.svg"></a>
</p>

---

## What James Can Do

James is not a chatbot. James is a **full agent platform** that thinks before it acts, remembers everything, and runs anywhere you work.

### 🧠 Planner-First Intelligence

Every message you send passes through a **meta-planner** before any agent touches it. The planner decomposes your request into tasks, assigns a risk level to each (read-only / additive / destructive), and displays the plan live as a streaming task list. You see exactly what James intends to do before he does it.

### 🤖 Six Specialised Agent Types

| Agent | What it does |
|-------|-------------|
| **Chat** | Conversational AI with persistent memory injection |
| **Code** | Full agentic coding loop with filesystem tools, search, and diff generation |
| **Research** | Deep research with web search, content retrieval, and citation management |
| **Desktop Control** | Takes over macOS/Linux screen with vision loop and input injection |
| **Browser Control** | Drives a dedicated Chrome session via CDP — no extensions required |
| **Security** | Bounded filesystem scanning and analysis agent |

### 🔒 Two Execution Modes

- **Direct mode** (default): James acts immediately and tells you exactly what he did.
- **Confirmed mode**: Destructive tasks pause for your approval before executing. You unblock them with a single click — or from your phone.

A **three-level inheritance** cascade applies your mode preference at account → project → session level, so you can set defaults globally and override per session.

### 💾 Persistent Memory Across Every Session

After every session, James automatically extracts key insights and stores them as **vector memories** (pgvector). When you start a new session, relevant memories are injected into the context window automatically. You can review, edit, and delete memories from a dedicated UI. Nothing is hidden.

### 🌐 Multi-Surface. One Platform.

Run James from wherever you work:

- **Web app** — full-featured React-inspired Vue 3 SPA
- **Desktop app** — native macOS and Linux shell via Tauri 2.0
- **Mobile** — Flutter remote viewer and controller with QR host binding
- **Telegram** — thread-to-session routing, voice transcription, confirmation prompts, and all slash commands
- **Office Add-ins** — Word, Excel, and PowerPoint integration via Office.js with device code auth
- **Chrome Extension** — Manifest V3 extension for CDP-controlled browser sessions

### 🌍 Multi-Host Cluster

Register multiple hosts running James. The planner routes tasks to the best available host based on health, load, and session affinity. Hosts heartbeat continuously; the cluster marks degraded or offline nodes automatically. Inter-host communication uses mTLS for transport security.

### 🔑 Enterprise-Grade Auth

- OAuth 2.0 with **Google, Microsoft, and GitHub**
- TOTP and **WebAuthn MFA** (hardware keys)
- JWT access + refresh tokens with automatic rotation
- **Device code flow** for CLI and add-in auth without a browser redirect
- All tokens are short-lived; refresh tokens rotate on every use

### 📊 Token Tracking & Budget Alerts

Every API call records input tokens, output tokens, and cost. You see a live cost counter on every session view. Set a global budget and James will warn you when you're approaching it or exceeding it. Per-model summaries help you understand where your spend goes.

### 🛠️ Fully Extensible

- **Skills** — versioned slash commands (`/dream`, `/summarise`, your own) synced from the filesystem, scoped per account/project/session
- **Plugins** — install, enable, disable, and remove capability packs
- **Hooks** — event-driven webhooks and command triggers for `pre_tool_use`, `post_tool_use`, `task_start`, `task_complete`, and 12 other lifecycle events
- **Channels** — configure Telegram, Slack, and custom MCP-backed channels with per-channel session routing
- **Personality profiles** — six built-in presets (Butler, Collaborator, Analyst, Coach, Editor, Silent) plus fully custom system prompts, cascading through account → project → session

### ⚡ Real-Time Everything

Phoenix Channels power every live surface: streaming agent responses, live task lists, planner step updates, and host heartbeats all flow over WebSocket. The frontend auto-reconnects with exponential backoff. Desktop and mobile clients stay in sync.

### 🔍 Hybrid Search

Search across all your sessions with a single query. James combines **PostgreSQL full-text search** (tsvector) with **semantic similarity search** (pgvector) and merges results by score. Find that idea from three weeks ago in seconds.

---

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

## Development

Each component follows a **zero-install** principle — given the base runtime, running the setup command installs everything locally:

```bash
make backend-setup     # mix deps.get && mix compile
make frontend-setup    # npm ci
make mobile-setup      # flutter pub get
make pipeline-setup    # poetry install
```

## Test Coverage

| Component  | Tests | Coverage Target |
|------------|-------|-----------------|
| Backend    | 481   | ≥50% (line)     |
| Frontend   | 146   | ≥70% (line)     |
| Pipeline   | —     | ≥90% (line)     |

Run with coverage:

```bash
make test-coverage
```

## License

[MIT](LICENSE)
