# James the Butler — Platform Specification

**Version:** 1.2
**Status:** Final — Ready for Implementation
**Owner:** Andre / EPL R&D

---

## 1. Vision

James the Butler is an AI-native agent platform. It gives you a single surface to run, observe, and interact with AI agents across chat, coding, research, computer use, Office, and mobile — all orchestrated by a central planner and routed through OpenClaw.

You run it as a web app, a desktop app (macOS and Linux), from your phone, or from inside Word, Excel, and PowerPoint. Every session is persistent and named. Every action is planned before it executes. Every cost is visible. James remembers context across sessions, adapts his personality to your preferences, and asks before doing only when you ask him to.

---

## 2. Core Principles

**Planner-first execution.** No agent runs a task without a planner reviewing it first. The planner maintains a live task list. When new input arrives, it updates the list before continuing.

**Progressive disclosure.** The UI shows you what you need now. Detail is one click away. Nothing is hidden permanently.

**Lazy loading.** Sessions, history, and agent output load on demand. The platform does not block on data it does not need yet.

**Background by default.** Any task the planner marks as parallelizable runs in a sub-session. Sub-sessions stream their activity live. You can watch or ignore them.

**Transparent cost.** Every interaction shows tokens consumed and their price in your configured currency.

**Persistent memory.** James extracts context from all interactions automatically and uses it to inform new sessions and tasks. You review and correct what he retains.

**Direct by default.** James acts without confirmation unless you switch to Confirmed mode. When he does act, he tells you exactly what he did.

---

## 3. Execution Modes

James operates in one of two execution modes at all times. The active mode is visible as a persistent toggle on every surface — web, desktop, mobile, Office add-ins, and Telegram.

### 3.1 Direct Mode (Default)

James executes all tasks immediately without a confirmation step. After completing a destructive or irreversible action, he surfaces a clear status message describing exactly what was done. In Office add-ins, native undo (Ctrl+Z) is the safety net for document changes.

### 3.2 Confirmed Mode

The planner tags every task with a risk level:

- **Read-only** — no side effects. Executes immediately even in Confirmed mode.
- **Additive** — creates new content without modifying or deleting existing content. Executes immediately even in Confirmed mode.
- **Destructive** — modifies, deletes, overwrites, or performs irreversible operations.

Only destructive tasks require approval in Confirmed mode. The approval request lists the destructive tasks specifically, not the full task breakdown. Read-only and additive tasks proceed without interruption.

**Approval mechanisms by surface:**

| Surface | Confirmed mode approval |
|---|---|
| Web / Desktop | Structured diff view — approve or reject before changes apply |
| Mobile | Tap-to-confirm screen |
| Office add-ins | Structured diff view at the slide / cell range / paragraph level |
| Telegram | James sends a summary message listing proposed destructive actions and waits for a reply. Timeout: 10 minutes (configurable). If no reply, task moves to blocked status. |

### 3.3 Mode Inheritance

Execution mode follows the same three-level inheritance hierarchy as personality: account level, project level, session level. The most specific level wins. You change mode mid-session at any time — the change applies to the next action forward, not retroactively.

---

## 4. System Architecture

### 4.1 Backend

- **Runtime:** Elixir with Phoenix
- **Real-time:** Phoenix Channels (WebSocket) for streaming agent output, live command logs, and session state updates
- **Database:** PostgreSQL via Ecto — sessions, tasks, agent runs, token ledger, user accounts, MCP configs, skills registry, host registry, Telegram thread mappings, memory store, personality profiles, execution mode settings
- **Vector search:** pgvector extension on the existing PostgreSQL instance — semantic memory retrieval and document chunk retrieval. No separate vector store.
- **Embeddings:** `james-server` exposes a `/embeddings` endpoint used by all clients (web, mobile, Office add-ins) to generate vectors. Consistent embedding model across the platform.
- **Background jobs:** Oban for durable task queuing including memory extraction jobs
- **Process model:** Each agent sub-session runs as a supervised Elixir GenServer. Each host's OpenClaw is the local orchestrator process. The global meta-planner runs as a GenServer on the designated primary host.

### 4.2 Frontend

- **Framework:** Vue 3 (Composition API)
- **Build tool:** Vite
- **Documentation and support pages:** VitePress
- **Desktop packaging:** Tauri (macOS and Linux). The same Vue codebase runs in both web and desktop modes. Platform-specific capabilities (filesystem access, native notifications) are gated behind Tauri API calls.
- **State management:** Pinia
- **Real-time:** Phoenix socket client for live session streaming

### 4.3 Mobile Application

- **Framework:** Flutter / Dart (iOS and Android)
- **Access model:** Remote viewer and controller. The mobile app connects to your running James instance. It does not run agents locally.
- **Setup:** One-time QR code scan binds the app to a specific host. The QR encodes a signed, time-limited token (5-minute expiry, single-use). The app stores the binding as a named computer profile in the device's secure enclave.
- **Computer switching:** You bind to multiple hosts. Switch between them from the app settings. Each host shows its sessions independently, ordered by last used.
- **Live stream:** WebRTC. The host captures the Wayland compositor output via PipeWire, encodes it with H.264, and pushes it as a WebRTC track. The mobile app receives it via Flutter's WebRTC package. Resolution and frame rate adapt automatically on degraded connections. A bundled STUN/TURN server ships with the Phoenix deployment. The stream is scoped to a single application window or the full desktop.

### 4.4 Office Add-ins

- **Standard:** Office.js (Microsoft Add-in standard). Works on Word, Excel, and PowerPoint on desktop and web. No COM automation — cross-platform by default.
- **Repository:** `james-office` — all three add-ins in one repo, sharing auth, session management, API client, and chunking logic.
- **Transport:** Office.js add-ins run inside a sandboxed iframe. All agent communication goes to `james-server` over the existing REST and WebSocket API.
- **Authentication:** Device code flow, one-time per add-in installation.
- **Session integration:** Add-ins connect to existing sessions or create new ones.
- **Execution mode in Office:** Direct mode relies on native undo. Confirmed mode shows a structured diff before writing.
- **Default personality:** The "Editor" preset is pre-selected when creating a new session from an Office add-in.
- **Memory:** Memory extraction is on by default for Office sessions. A visible toggle in the sidebar turns it off per session for sensitive documents.

### 4.5 Document Context — Progressive Retrieval

Document content is never passed to the agent in full unless the document is very small (under a configurable token threshold). Instead:

1. On document load (or on save), the add-in sends document chunks to `james-server`'s `/embeddings` endpoint.
2. Chunks are stored in session-scoped add-in storage as vectors.
3. When you send a message, the add-in runs a semantic search against the stored chunks and injects only the top-N most relevant ones into the agent's context window.
4. As the conversation evolves, different chunks surface based on the current query.

**Chunking strategy by application:**

| Application | Chunk unit |
|---|---|
| Word | Paragraph |
| Excel | Named range first. If no named ranges exist, sheet. |
| PowerPoint | One slide per chunk |

### 4.6 OpenClaw — Local Orchestrator

Each host runs one OpenClaw instance. It:

- Manages local session lifecycle: start, suspend, resume, terminate
- Runs local agent workers (Claude Code, research agents, computer use, etc.)
- Executes tasks routed to it by the global meta-planner
- Streams session state to the frontend, mobile clients, and the primary host
- Exposes a Telegram bot interface for direct interaction with local sessions
- Registers itself with the primary host on startup

### 4.7 Global Meta-Planner

The meta-planner runs on the designated primary host. It is the single coordinator for cross-host work.

**Responsibilities:**

1. Receive all input — user messages, Telegram commands, Office add-in requests, scheduled triggers
2. Decompose input into tasks and tag each with a risk level (read-only, additive, destructive)
3. Determine which host each task should run on, based on session location and host capabilities
4. In Confirmed mode, surface destructive tasks for approval before dispatch
5. Route approved tasks to the appropriate OpenClaw instance
6. Aggregate status across all hosts and surface it in the UI
7. Maintain the Telegram thread-to-session mapping

**Failure behavior:** If the primary host goes down, all other hosts continue running their active sessions. They stop receiving routed tasks from the meta-planner until the primary recovers.

---

## 5. Multi-Host Architecture

### 5.1 Host Configuration

You configure each host in settings with a name, address, and connection credentials. One host is designated as primary. The others are workers.

### 5.2 Session Pinning

Sessions are pinned to the host they start on. They do not migrate.

### 5.3 Cross-Host Task Execution

When the meta-planner fans a task across multiple hosts, it dispatches sub-tasks to each host's OpenClaw. Each host runs its sub-task as a local background sub-session. Results aggregate back to the primary and surface in the global task list.

---

## 6. Authentication and Security

### 6.1 SSO Providers

Google, Microsoft, and GitHub OAuth 2.0.

### 6.2 MFA

MFA is mandatory. TOTP and WebAuthn supported. No SMS.

### 6.3 Session Security

- Short-lived JWTs with refresh token rotation
- Mobile credentials in device secure enclave
- QR setup tokens: 5-minute expiry, single-use
- All inter-host communication uses mTLS

---

## 7. Model Configuration

### 7.1 Supported Providers

| Provider | Auth Method |
|---|---|
| Anthropic (Claude) | API key |
| OpenAI (GPT series) | API key |
| OpenAI Codex | API key |
| Google (Gemini) | API key |
| MiniMax | OAuth or API key |
| Ollama | Local endpoint |
| LM Studio | Local endpoint |
| Any OpenAI-compatible endpoint | API key or none |

### 7.2 Model Assignment

Each agent type has a default model per host. Override at host or session level.

### 7.3 Local Models

Configure by entering base URL. No special setup beyond the running server.

---

## 8. Agent Modalities

| Agent | Description |
|---|---|
| **Chat** | Persistent multi-turn conversation with file uploads and memory |
| **Code** | Full filesystem + shell access, PR creation, architecture diagrams |
| **Research** | Web search, source synthesis, structured reports |
| **Computer Use** | Wayland desktop control, browser automation, WebRTC live stream |
| **Security** | Source code and PR analysis, structured findings with severity |

---

## 9. Session Management

Every session has: name, host assignment, project assignment, agent type, personality, execution mode, timestamps, status (active/idle/suspended/terminated). Sessions persist across host restarts via PostgreSQL.

---

## 10. Planner

Every input enters the meta-planner before any agent acts. The planner: parses input into tasks, tags risk levels, checks conflicts, routes to hosts, surfaces destructive tasks for approval in Confirmed mode, dispatches background tasks, maintains the visible task list.

---

## 11. Sub-Sessions and Background Execution

Each background task runs in its own sub-session (supervised Elixir GenServer). Shows: live command log, status, token cost, file diff view. Visible in Sessions panel.

---

## 12. Projects

Projects group sessions, repositories, shared context, and a project-level chat across hosts.

**Agent Roles:** Architect, Developer, TDD, PR Review, Security, Spec Evolution.

**Dashboard:** Repository health, open PRs, test pass rate, security findings, token cost.

---

## 13. Memory

Implicit extraction from all interactions via background Oban jobs. Stored as vectors in PostgreSQL/pgvector. Semantic retrieval at session start and on each message. Review surface for viewing, editing, and deleting memories.

---

## 14. Personality and Style

Three-level hierarchy (account > project > session). Built-in presets: Butler, Collaborator, Analyst, Coach, Editor, Silent. Custom profiles via natural language.

---

## 15. MCP Integration

Pre-configured: JIRA, Figma, GitHub, Filesystem. Custom servers via name + transport + params. Per-session MCP scope.

---

## 16. Skills

Reusable instruction bundles as Markdown files. Versioned by content hash. Attach at project, session, or task level.

---

## 17. Working Directory Management

Per-host filesystem paths. Sessions can have multiple. Git status displayed in session panel.

---

## 18. Token Usage and Cost

Per-session/task tracking: input tokens, output tokens, model, cost in configured currency. Dashboard by model, agent type, host, time period. Budget alerts.

---

## 19. Telegram Integration

Phoenix process on primary host. Full platform access. Voice messages transcribed via Whisper. Thread-to-session routing. Confirmed mode with configurable timeout.

---

## 20. Computer Use — Linux Sandbox

Wayland compositor per session. PipeWire capture for WebRTC. GPU acceleration. Process isolation.

---

## 21. UI Structure

Sidebar: Sessions, Projects, Task List, Memory, Hosts, OpenClaw Activity, Settings, Mobile Setup. Session view: Context (left), Conversation (center), Tasks/Tokens/Memories (right).

---

## 22. Repository Structure

| Repository | Contents |
|---|---|
| `james-server` | Elixir/Phoenix backend, OpenClaw, meta-planner, Telegram bot, Oban jobs, PostgreSQL migrations, `/embeddings` endpoint, Docker Compose |
| `james-app` | Vue 3 frontend, Tauri desktop wrapper, VitePress docs |
| `james-mobile` | Flutter/Dart iOS and Android app |
| `james-office` | Office.js add-ins for Word, Excel, PowerPoint |

---

## 23. Deployment

Phoenix release with env var config. Tauri desktop with Phoenix sidecar. Docker Compose for self-hosted. Ecto migrations run on startup. Multi-host via shared secret + mTLS.

---

## 24. Out of Scope for v1.0

- Windows desktop support
- Voice input in chat agent
- Agent-to-agent tool delegation across providers
- Built-in billing/subscription management
- Public API beyond Telegram
- Session migration between hosts
- Memory isolation between projects

---

*End of specification v1.2*
