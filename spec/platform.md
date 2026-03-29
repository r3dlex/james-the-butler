# James the Butler — Platform Specification

**Version:** 1.4
**Status:** Final — Ready for Implementation
**Owner:** Andre / EPL R&D

---

## 1. Vision

James the Butler is an AI-native agent platform. It gives you a single surface to run, observe, and interact with AI agents across chat, coding, research, full desktop control, browser control, Office, and mobile — all orchestrated by a central planner and routed through OpenClaw.

You run it as a web app, a desktop app (macOS and Linux), from your phone, from inside Word, Excel, and PowerPoint, or from a Chrome extension controlling a dedicated browser session. Every session is persistent and named. Every action is planned before it executes. Every cost is visible. James remembers context across sessions, adapts his personality to your preferences, and asks before doing only when you ask him to.

---

## 2. Core Principles

**Planner-first execution.** No agent runs a task without a planner reviewing it first. The planner maintains a live task list. When new input arrives, it updates the list before continuing.

**Progressive disclosure.** The UI shows you what you need now. Detail is one click away. Nothing is hidden permanently.

**Lazy loading.** Sessions, history, and agent output load on demand. The platform does not block on data it does not need yet.

**Background by default.** Any task the planner marks as parallelizable runs in a sub-session. Sub-sessions stream their activity live. You can watch or ignore them.

**Transparent cost.** Every interaction shows tokens consumed and their price in your configured currency.

**Persistent memory.** James extracts context from all interactions automatically and uses it to inform new sessions and tasks. You review and correct what he retains.

**Direct by default.** James acts without confirmation unless you switch to Confirmed mode. When he does act, he tells you exactly what he did.

**Minimal footprint.** James uses the minimum resources needed for the current task. Working files are cleaned up after use. Intermediate artifacts are discarded unless explicitly retained.

---

## 3. Execution Modes

James operates in one of two execution modes at all times. The active mode is visible as a persistent toggle on every surface — web, desktop, mobile, Office add-ins, Chrome extension, and Telegram.

### 3.1 Direct Mode (Default)

James executes all tasks immediately without a confirmation step. After completing a destructive or irreversible action, he surfaces a clear status message describing exactly what was done. In Office add-ins, native undo (Ctrl+Z) is the safety net for document changes.

### 3.2 Confirmed Mode

The planner tags every task with a risk level:

- **Read-only** — no side effects. Executes immediately even in Confirmed mode.
- **Additive** — creates new content without modifying or deleting existing content. Executes immediately even in Confirmed mode.
- **Destructive** — modifies, deletes, overwrites, or performs irreversible operations.

Only destructive tasks require approval in Confirmed mode.

**Approval mechanisms by surface:**

| Surface | Confirmed mode approval |
|---|---|
| Web / Desktop | Structured diff view — approve or reject before changes apply |
| Mobile | Tap-to-confirm screen |
| Office add-ins | Structured diff view at the slide / cell range / paragraph level |
| Chrome extension | Inline approval panel in the extension sidebar |
| Telegram | Summary message with 10-minute configurable timeout |

### 3.3 Mode Inheritance

Execution mode follows the same three-level inheritance hierarchy as personality: account level, project level, session level. The most specific level wins.

---

## 4. System Architecture

### 4.1 Backend

- **Runtime:** Elixir with Phoenix
- **Real-time:** Phoenix Channels (WebSocket) for streaming agent output, planner reasoning steps, live command logs, and session state updates
- **Database:** PostgreSQL via Ecto — sessions, tasks, agent runs, token ledger, user accounts, MCP configs, skills registry, host registry, Telegram thread mappings, memory store, personality profiles, execution mode settings, tab group state, execution history, output artifact metadata
- **Vector search:** pgvector extension on the existing PostgreSQL instance
- **Embeddings:** `/embeddings` endpoint used by all clients (web, mobile, Office add-ins, Chrome extension)
- **Background jobs:** Oban for durable task queuing including memory extraction jobs, tab lifecycle management, working file cleanup, and narrative summary generation
- **Process model:** Each agent sub-session runs as a supervised Elixir GenServer. Each host's OpenClaw is the local orchestrator process. The global meta-planner runs as a GenServer on the designated primary host.

### 4.2 Frontend

- **Framework:** Vue 3 (Composition API)
- **Build tool:** Vite
- **Documentation and support pages:** VitePress
- **Desktop packaging:** Tauri (macOS and Linux)
- **State management:** Pinia
- **Real-time:** Phoenix socket client for live session streaming

### 4.3 Mobile Application

- **Framework:** Flutter / Dart (iOS and Android)
- **Access model:** Remote viewer and controller. Does not run agents locally.
- **Setup:** One-time QR code scan binds the app to a host. 5-minute expiry, single-use token in device secure enclave.
- **Live stream:** WebRTC via PipeWire (Linux) or macOS screen capture daemon. H.264, adaptive resolution.

### 4.4 Office Add-ins

- **Standard:** Office.js (Microsoft Add-in standard). Word, Excel, PowerPoint.
- **Repository:** `james-office`
- **Authentication:** Device code flow, one-time per installation.

### 4.5 Document Context — Progressive Retrieval

Chunk → embed → semantic search. Chunks by paragraph (Word), named range/sheet (Excel), slide (PowerPoint).

### 4.6 OpenClaw — Local Orchestrator

Each host runs one OpenClaw instance. It:

- Manages local session lifecycle: start, suspend, resume, terminate
- Runs local agent workers (Claude Code, research agents, desktop control, browser control, etc.)
- Manages the CDP-controlled Chrome instance lifecycle on its host
- Manages the desktop control daemon on its host
- Executes tasks routed to it by the global meta-planner
- Streams session state to the frontend, mobile clients, and the primary host
- Exposes a Telegram bot interface for direct interaction with local sessions
- Registers itself with the primary host on startup

### 4.7 Global Meta-Planner

The meta-planner runs on the designated primary host. Receives all input — user messages, Telegram commands, Office add-in requests, Chrome extension requests, scheduled triggers. Streams decomposition steps to the UI in real time. Decomposes into tasks, tags risk levels, routes to hosts, surfaces destructive tasks for approval in Confirmed mode. Dispatches parallelizable tasks as parallel sub-sessions.

**Failure behavior:** If the primary host goes down, all other hosts continue running their active sessions independently.

---

## 5. Multi-Host Architecture

Sessions are pinned to the host they start on. The meta-planner dispatches cross-host sub-tasks. Each host runs its own OpenClaw with its own configuration.

---

## 6. Authentication and Security

- OAuth 2.0: Google, Microsoft, GitHub
- MFA mandatory: TOTP + WebAuthn. No SMS.
- Short-lived JWTs with refresh token rotation
- Mobile credentials in device secure enclave
- QR tokens: 5-minute expiry, single-use
- Inter-host communication: mTLS

---

## 7. Model Configuration

| Provider | Auth Method |
|---|---|
| Anthropic (Claude) | API key |
| OpenAI (GPT series) | API key |
| OpenAI Codex | API key (Responses API, no OAuth) |
| Google (Gemini) | API key |
| MiniMax | OAuth or API key |
| Ollama | Local endpoint |
| LM Studio | Local endpoint |
| Any OpenAI-compatible endpoint | API key or none |

Each agent type (chat, code, research, desktop control, browser control, security) has a default model per host. Override at host or session level.

---

## 8. Agent Modalities

### 8.1 Chat Agent

Persistent multi-turn conversation with file uploads and memory context.

### 8.2 Code Agent

Full filesystem + shell access, PR creation, architecture diagrams. Claude Code-equivalent.

### 8.3 Research Agent

Web search, source synthesis, structured reports (Markdown/PDF export).

### 8.4 Desktop Control Agent

Full control of the host desktop — macOS or Linux. Replaces the previous sandboxed computer use agent. See §21 for full implementation detail.

### 8.5 Browser Control Agent

Controls a dedicated CDP-controlled Chrome instance on the host. Navigates pages, interacts with DOM elements, fills forms, extracts content. See §22 for full implementation detail.

### 8.6 Security Agent

Source code and PR analysis, structured findings with severity ratings and remediation steps.

---

## 9. Session Management

### 9.1 Session Properties

Every session has: name, host assignment, project assignment, agent type, personality, execution mode, timestamps, status (active/idle/suspended/terminated). Sessions persist across host restarts via PostgreSQL. Tab group state is persisted for browser control sessions. Session lists on all surfaces (web, desktop, mobile, Office, Chrome extension, Telegram) are ordered by last used.

**Keep Intermediates flag.** Each session has a "Keep Intermediates" toggle (default: off). When off, working files are cleaned up after task completion and only final deliverables are retained. When on, all intermediate artifacts are preserved for the session's lifetime.

---

## 10. Planner

### 10.1 Core Behaviour

Every input — user messages, Telegram commands, Office add-in requests, Chrome extension requests, scheduled triggers — enters the meta-planner before any agent acts. The planner: parses input into tasks, tags risk levels, checks conflicts, routes to hosts, surfaces destructive tasks for approval in Confirmed mode, dispatches background tasks, maintains the visible task list.

### 10.2 Planner Visibility

The planner's reasoning process streams to the UI in real time. As the planner decomposes a request, each reasoning step appears in the center panel so the user can follow the decision-making process before tasks begin executing.

### 10.3 Task List Behaviour

The task list shows all current and recent tasks with risk levels and live status. Completed tasks show strikethrough styling. Task groups auto-collapse 30 minutes after all tasks in the group complete. The task list is visible in the right panel of the session view and in the global Task List sidebar entry.

---

## 11. Sub-Sessions and Background Execution

Each background task runs in its own sub-session (supervised Elixir GenServer). Shows: live command log (shell commands, tool calls, file writes, DOM interactions, desktop actions), status, token cost, file diff view.

---

## 12. View Mode

View Mode provides a live observation panel for active agent sessions.

- **Live WebRTC panel:** Real-time video stream of desktop control or browser control sessions, embedded directly in the session view.
- **Multi-agent view:** Thumbnail grid showing all active agent sub-sessions. Click any thumbnail to expand to full view.
- **Artifact preview:** Inline preview of output artifacts (documents, images, code files) as they are produced, without leaving the session view.

View Mode is accessible from the right panel of the session view (switchable with the Task List).

---

## 13. Output Artifact Management

### 13.1 Artifact Types

- **Deliverables:** Final outputs requested by the user (documents, code, reports, images). Always retained.
- **Working files:** Intermediate files created during task execution (drafts, temp data, scratch files). Cleaned up automatically unless Keep Intermediates is enabled on the session (see §9.1).

### 13.2 Keep Intermediates

When the session-level "Keep Intermediates" flag is on, all working files are preserved for the session's lifetime. When off (default), an Oban job runs after task completion to clean up working files.

### 13.3 Execution History

Every session maintains an execution history consisting of:

- **Structured log:** Machine-readable record of every agent action, tool call, file operation, and decision point.
- **Narrative summary:** Human-readable summary generated by an Oban background job after task completion. Summarizes what was done, key decisions, and final outcomes.

Both are stored in PostgreSQL and viewable in the session detail panel.

---

## 14. Projects

Projects group sessions, repositories, shared context, and a project-level chat across hosts.

**Agent Roles:** Architect, Developer, TDD, PR Review, Security, Spec Evolution.

**Dashboard:** Repository health, open PRs, test pass rate, security findings, token cost.

---

## 15. Memory

Implicit extraction from all interactions via background Oban jobs. Stored as vectors in PostgreSQL/pgvector. Semantic retrieval at session start and on each message. Review surface for viewing, editing, and deleting memories.

---

## 16. Personality and Style

Three-level hierarchy (account > project > session). Built-in presets: Butler, Collaborator, Analyst, Coach, Editor, Silent. Custom profiles via natural language.

---

## 17. MCP Integration

Pre-configured: JIRA, Figma, GitHub, Filesystem. Custom servers via name + transport + params. Per-session MCP scope.

---

## 18. Skills

Reusable instruction bundles as Markdown files. Versioned by content hash. Attach at project, session, or task level.

---

## 19. Working Directory Management

Per-host filesystem paths. Sessions can have multiple. Git status displayed in session panel.

---

## 20. Token Usage and Cost

Per-session/task tracking. Dashboard by model, agent type, host, time period. Budget alerts.

---

## 21. Desktop Control Agent

The Desktop Control Agent gives James full control of the host desktop — macOS or Linux — on your behalf.

### 21.1 Vision Loop

Screenshot-per-action cycle:

1. Capture screenshot of current desktop state
2. Send screenshot + task context to model
3. Receive next action (click, type, scroll, key combo, drag)
4. Execute action via platform-specific input injection
5. Capture new screenshot and repeat

Screenshots used by the agent for its vision loop are not stored in the database. They are transient — used for the current action step only and discarded.

A configurable debug option switches vision input from screenshots to the live WebRTC stream (testing/debugging only).

### 21.2 Linux Implementation

- **Display capture:** PipeWire captures Wayland compositor output
- **Input injection:** Wayland input protocols (libinput / wlroots virtual input)
- **GPU acceleration:** Via Wayland compositor
- **Isolation:** Each session in its own Wayland compositor namespace
- **Live stream:** PipeWire → WebRTC (H.264, STUN/TURN bundled in Phoenix)

### 21.3 macOS Implementation

- **Helper process:** A privileged launchd daemon installed via a guided setup wizard. Starts automatically at login. Communicates with `james-server` over mTLS.
- **Display capture:** macOS Screen Capture API.
- **Primary input injection:** Accessibility API (AXUIElement) for UI element targeting by role and label.
- **Fallback input injection:** CGEvent for low-level coordinate-based mouse and keyboard injection when the Accessibility tree is unavailable or incomplete.
- **Live stream:** Screen capture frames feed into WebRTC via H.264, same pipeline as Linux.

### 21.4 macOS Accessibility Fallback Cases

The Accessibility API fails or returns incomplete trees for the following categories of applications. The agent falls back to CGEvent coordinate-based targeting in all cases, using the screenshot as the visual grounding source for element location.

| Application type | Reason AX fails | Fallback |
|---|---|---|
| Electron apps (VS Code, Slack, Discord, Notion, Figma desktop) | Chromium renders UI in a sandboxed web layer with no native AX tree | CGEvent + visual grounding. For Electron specifically: CDP injection into the Electron renderer process is also available, giving full DOM access identical to the browser control agent. |
| GPU-rendered apps and games | Metal / OpenGL surfaces are opaque to AX | CGEvent + visual grounding only |
| Web content inside browsers | Rendered in a sandboxed process; AX sees the frame but not the DOM | Use the Browser Control Agent instead — CDP provides full DOM access |
| Java apps (Swing / AWT) | AX support inconsistent on modern macOS | CGEvent + visual grounding |
| Terminal emulators (iTerm2, Alacritty, Kitty) | Expose minimal AX structure | CGEvent + visual grounding |

### 21.5 Shared Behaviour

Both implementations share the same session interface. Desktop control sessions look and behave identically on macOS and Linux.

### 21.6 Live Stream Vision Mode

Toggle in session settings switches vision source from screenshots to live WebRTC stream. For testing/debugging only — stream latency and encoding artifacts can degrade model decision quality.

---

## 22. Browser Control Agent

### 22.1 Architecture

Uses Chrome DevTools Protocol (CDP) to control a dedicated Chrome instance on the host. One shared Chrome instance per host, launched and managed by OpenClaw. The James Chrome extension is installed inside this CDP-controlled instance only.

### 22.2 Chrome Instance Lifecycle

- **Launch:** On demand when first browser control session starts
- **Persistence:** Stays alive until host shutdown or OpenClaw stop
- **Crash recovery:** OpenClaw relaunches automatically, restores tab groups from PostgreSQL
- **Minimum footprint:** James keeps minimum tabs needed for active tasks (never zero)

### 22.3 Tab Groups

Chrome Tab Groups API. Every browser control session has its own named, color-coded tab group.

- Tab group closes after 24 hours of session inactivity
- James proactively closes irrelevant tabs within a group
- Suspended sessions: tab group collapses but does not close
- Extension always maintains at least one open tab

### 22.4 Chrome Extension

- **Repository:** `james-chrome` — standalone repo, Manifest V3
- **Scope:** Runs exclusively inside the CDP-controlled Chrome instance (not Chrome Web Store)
- **Sidebar:** Session conversation, active tab group, task status, token cost, execution mode toggle
- **Authentication:** Device code flow (same as Office add-ins)
- **Communication:** WebSocket (real-time) + REST (session management)

### 22.5 CDP Control Layer

CDP for precision automation: URL navigation, DOM element clicks by selector, form filling, page content reading, JavaScript execution, network interception, full-page screenshots for vision loop. CDP connection managed by OpenClaw, not the extension.

### 22.6 Agent Vision Loop

Same screenshot-per-action cycle as desktop control, scoped to active browser tab. CDP `Page.captureScreenshot` provides visual input. Screenshots are transient — used for the current action step, not stored. Debug live stream option available.

---

## 23. Telegram Integration

Phoenix process on primary host. Full platform access including desktop control and browser control. Voice transcription via Whisper. Thread-to-session routing. Confirmed mode with configurable timeout.

---

## 24. UI Structure

### 24.1 Primary Navigation

```
Sidebar
├── Sessions (ordered by last used, searchable)
│   ├── Chat
│   ├── Code
│   ├── Research
│   ├── Desktop Control
│   └── Browser Control
├── Projects
│   ├── Project chat
│   ├── Project sessions
│   ├── Project dashboard
│   └── Project settings
├── Task List (planner — global, risk levels)
├── Memory
├── Hosts
│   ├── Host status
│   ├── Per-host session list
│   └── Host settings
├── OpenClaw Activity
├── Settings
│   ├── Models (per host)
│   ├── MCP Servers
│   ├── Working Directories (per host)
│   ├── Skills (conflict resolution mode)
│   ├── Personality (account-level default + custom profiles)
│   ├── Execution Mode (account-level default)
│   ├── Memory (extraction prompt override)
│   ├── Security (SSO, MFA)
│   ├── Telegram (Confirmed mode timeout)
│   ├── Desktop Control (macOS daemon setup wizard)
│   └── Billing / Token Usage
└── Mobile App Setup (QR code generation)
```

### 24.2 Session View

- **Left:** Context — host, project, working directories, MCP servers, skills, personality, execution mode toggle, Keep Intermediates toggle
- **Center:** Planner reasoning stream (decomposition steps shown in real time), then conversation or agent output stream
- **Right:** Switchable between Task List (risk levels, token counter, sub-session activity, memories) and View Mode (live WebRTC panel, multi-agent thumbnails, artifact preview)

### 24.3 Project View

- **Top:** Repository matrix with health indicators and host assignments
- **Left:** Project-level chat
- **Right:** Agent activity feed across all project sessions

---

## 25. Repository Structure

| Repository | Contents |
|---|---|
| `james-server` | Elixir/Phoenix backend, OpenClaw, meta-planner, Telegram bot, Oban jobs, PostgreSQL migrations, `/embeddings` endpoint, CDP process manager, desktop daemon communication layer, Docker Compose |
| `james-app` | Vue 3 frontend, Tauri desktop wrapper, VitePress docs |
| `james-mobile` | Flutter/Dart iOS and Android app |
| `james-office` | Office.js add-ins for Word, Excel, PowerPoint |
| `james-chrome` | Chrome extension (Manifest V3) for the CDP-controlled browser instance |

---

## 26. Deployment

### 26.1 Web and Desktop

Phoenix release with env var config. Tauri desktop with Phoenix sidecar. Self-contained.

### 26.2 Docker

Docker Compose for Phoenix app + PostgreSQL (pgvector). Multi-host via shared secret + mTLS.

### 26.3 macOS Desktop Control Setup

Signed and notarized installer package. Registers launchd daemon and launches guided permission wizard (Accessibility + Screen Recording). No admin password beyond initial installation.

### 26.4 Database Migrations

Ecto migrations run automatically on startup.

---

## 27. Out of Scope for v1.0

- Windows desktop support
- Voice input in the chat agent (voice messages via Telegram are supported)
- Agent-to-agent tool delegation across provider boundaries
- Built-in billing and subscription management
- Public API for third-party integrations beyond Telegram
- Session migration between hosts
- Memory isolation between projects
- Chrome Web Store distribution of the James extension
- Firefox or Safari browser control support

---

*End of specification v1.4*
