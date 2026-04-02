# Frontend Specification (Vue 3)

For the full platform specification, see [platform.md](platform.md) §4.2, §24.

## Purpose

The web frontend (`james-app`) provides the primary UI for James the Butler. The same codebase runs as a web app and as a Tauri desktop app (macOS and Linux).

## Technology

- **Runtime**: Node.js 20+
- **Framework**: Vue 3 with Composition API (`<script setup>`)
- **Language**: TypeScript
- **Build**: Vite
- **Desktop**: Tauri (macOS and Linux)
- **Documentation**: VitePress
- **State**: Pinia
- **Real-time**: Phoenix channels JS client
- **Testing**: Vitest + Vue Test Utils
- **Linting**: ESLint + Prettier

## Key Features

- Session management (chat, code, research, computer use, security agents)
- Project dashboards with repository health, agent activity, token cost
- Planner task list with risk levels and live status
- Memory review panel (view, edit, delete, search)
- Multi-host management with session pinning
- Execution mode toggle (Direct / Confirmed) with structured diff view
- Personality preset selection and custom profile editor
- Token usage dashboard with budget alerts
- MCP server and skill configuration
- Mobile QR code generation for host binding
- View Mode panel (live WebRTC stream, multi-agent thumbnails, artifact preview)
- Planner reasoning stream in center panel
- Task list with strikethrough completion and 30-min auto-collapse
- Full chat history loaded from the Phoenix channel join payload (no separate REST fetch)
- Non-blocking FIFO message queue — users can send messages while James is streaming; queued messages drain automatically when the response completes
- Workspace + execution mode panel below ChatInput (Claude Desktop style)
- Folder-only picker (`webkitdirectory`) for working directory selection
- Sidebar session search clears automatically when the user navigates to a result

## UI Structure

```
Sidebar
├── Sessions (ordered by last used, searchable)
├── Projects (chat, sessions, dashboard, settings)
├── Task List (planner — global, risk levels)
├── Memory
├── Hosts (status, sessions, settings)
├── OpenClaw Activity
├── Settings (models, MCP, directories, skills, personality, auth, billing)
└── Mobile App Setup (QR)
```

## Session View

- **Left panel**: Context — host, project, working directories, MCP servers, skills, personality, execution mode
- **Center panel**: Conversation or agent output stream
- **Right panel**: Task list, token counter, sub-session activity, memories

## Zero-Install

```bash
cd frontend
npm ci          # Install exact dependency tree
```

## Testing

```bash
npm test             # Vitest suite
npm run test:coverage  # With coverage (target: 70%)
npm run lint         # ESLint + Prettier
```

## Internal Details

See `frontend/spec/README.md` for component tree, routing, store design, and Tauri integration.
