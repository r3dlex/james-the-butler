# API Endpoint Reference

For the full platform specification, see [platform.md](platform.md) SS4.1.
For backend context details, see [elixir.md](elixir.md).

---

## Purpose

Defines the HTTP and WebSocket API surface exposed by the Phoenix backend. All clients (web, desktop, mobile, Office add-ins, Chrome extension, Telegram bot) consume this API.

## Design

- Base URL: `/api`
- Format: JSON request and response bodies
- Auth: JWT Bearer token on all endpoints except `/health` and auth endpoints
- Errors: Standard HTTP status codes with `{"error": "message"}` body
- Pagination: Cursor-based via `?cursor=` and `?limit=` query params where applicable

---

## Auth

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/auth/login` | OAuth callback — exchanges provider code for JWT + refresh token |
| `POST` | `/api/auth/refresh` | Rotate refresh token, return new JWT |
| `POST` | `/api/auth/logout` | Revoke refresh token |
| `GET` | `/api/auth/me` | Return current user profile, execution mode, personality |
| `POST` | `/api/auth/device-code` | Device authorization flow for Office add-ins and Chrome extension |

## Sessions

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/sessions` | List sessions for current user (paginated) |
| `POST` | `/api/sessions` | Create session — accepts `name`, `project_id`, `agent_type`, `personality_id`, `execution_mode` |
| `GET` | `/api/sessions/:id` | Get session detail including status, host, message count |
| `PUT` | `/api/sessions/:id` | Update session metadata (name, execution mode, personality) |
| `DELETE` | `/api/sessions/:id` | Archive session (soft delete) |
| `POST` | `/api/sessions/:id/messages` | Send user message — triggers planner and agent execution |

## Projects

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/projects` | List projects for current user |
| `POST` | `/api/projects` | Create project with name, personality, execution mode |
| `GET` | `/api/projects/:id` | Get project detail |
| `PUT` | `/api/projects/:id` | Update project settings |
| `DELETE` | `/api/projects/:id` | Archive project |

## Tasks

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/tasks` | List tasks, filterable by `session_id`, `status`, `risk_level` |
| `GET` | `/api/tasks/:id` | Get task detail including sub-tasks and execution log |
| `POST` | `/api/tasks/:id/approve` | Approve a destructive task (Confirmed mode) |
| `POST` | `/api/tasks/:id/reject` | Reject a destructive task |

## Hosts

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/hosts` | List registered hosts with status |
| `GET` | `/api/hosts/:id` | Get host detail including mTLS fingerprint |
| `GET` | `/api/hosts/:id/sessions` | List active sessions on a host |

## Memory

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/memories` | List memories for current user (paginated, filterable by source session) |
| `PUT` | `/api/memories/:id` | Update memory content |
| `DELETE` | `/api/memories/:id` | Delete a memory entry |

## Token Usage

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/tokens/usage` | Token ledger entries, filterable by `session_id`, `model`, date range |
| `GET` | `/api/tokens/usage/summary` | Aggregated usage: total tokens, cost by model, cost by session |

## Embeddings

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/embeddings` | Generate embedding vector for input text. Used by all clients for semantic search |

## Provider OAuth (PKCE)

Used to connect LLM provider credentials (OpenAI, OpenAI Codex) via the browser-based OAuth 2.0 PKCE flow. Tokens are stored server-side; the frontend never handles raw secrets.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/providers/oauth/start` | ✓ JWT | Begin PKCE flow. Body: `{"provider_type": "openai"}`. Returns `{"auth_url": "…", "state_key": "…"}`. Open `auth_url` in a popup. |
| `GET` | `/api/providers/oauth/callback` | ✗ public | Receives the authorization code redirect from the provider. Exchanges code for tokens, persists config, marks state as `:completed`. Returns an HTML page that auto-closes the popup. |
| `GET` | `/api/providers/oauth/status/:state_key` | ✓ JWT | Poll for flow completion. Returns `{"status": "pending"}` or `{"status": "completed", "provider": {…}}`. |

> The callback endpoint is public (no JWT) because the browser is redirected here by the provider after the user approves — there is no opportunity to include a token in the redirect.

## Health

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check — no auth required. Returns `{"status": "ok"}` |

---

## WebSocket

**Endpoint:** `WS /socket`

Authenticated via JWT token param on connect. Uses Phoenix Channels for real-time communication.

### Channels

| Topic | Purpose |
|-------|---------|
| `session:*` | Stream agent output, message events, task status changes, artifact creation |
| `planner:*` | Stream planner reasoning steps and live task list updates |
| `host:*` | Host status changes, session routing events |

### Message Flow

1. Client joins `session:<id>` after creating or loading a session.
   The join reply payload includes `{"messages": [...]}` — the full prior message history for the session. Clients must consume this on join to display conversation history without a separate REST call.
2. User messages sent via REST (`POST /api/sessions/:id/messages`).
3. Agent output, planner steps, and task updates pushed over the channel in real time.
4. Desktop/browser control frames streamed via WebRTC (see [webrtc.md](webrtc.md)), signaled through the `session:*` channel.
