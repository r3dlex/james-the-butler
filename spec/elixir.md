# Backend Specification (Elixir/Phoenix)

For the full platform specification, see [platform.md](platform.md) §4.1, §4.6, §4.7.

## Purpose

The backend (`james-server`) is the central platform server. It runs the meta-planner, OpenClaw orchestrators, Telegram bot, memory system, and all API endpoints.

## Technology

- **Runtime**: Elixir 1.16+ / OTP 26+
- **Framework**: Phoenix 1.7+ with Bandit HTTP server
- **Database**: PostgreSQL 15+ via Ecto, with pgvector for semantic search
- **Background jobs**: Oban for durable task queuing
- **Real-time**: Phoenix Channels (WebSocket)
- **Auth**: OAuth 2.0 (Google, Microsoft, GitHub), JWT with refresh rotation, TOTP/WebAuthn MFA

## Core Subsystems

### Meta-Planner (GenServer)
- Runs on the designated primary host
- Receives all input (user messages, Telegram commands, Office requests, scheduled triggers)
- Decomposes into tasks, tags risk levels (read-only/additive/destructive)
- Routes tasks to the appropriate host's OpenClaw
- Surfaces destructive tasks for approval in Confirmed mode

### OpenClaw — Local Orchestrator (GenServer)
- One per host
- Manages local session lifecycle: start, suspend, resume, terminate
- Supervises agent worker GenServers (chat, code, research, computer use, security)
- Streams session state to clients and primary host
- Registers with primary host on startup

### Memory System
- Extraction: Oban jobs process conversation deltas with a fixed extraction prompt
- Storage: pgvector embeddings in PostgreSQL (no separate vector store)
- Retrieval: Semantic search at session start and per-message
- `/embeddings` endpoint for all clients

### Telegram Bot
- Phoenix process on primary host
- Thread-to-session routing
- Voice message transcription (Whisper)
- Confirmed mode with configurable timeout

## API Surface

- `GET/POST/PUT/DELETE /api/*` — RESTful JSON endpoints
- `WS /socket` — Phoenix Channels for real-time streaming
- `POST /api/embeddings` — Vector embedding generation

## Contexts

| Context | Responsibility |
|---|---|
| `Accounts` | User registration, OAuth, MFA, JWT management |
| `Sessions` | Session CRUD, persistence, host pinning |
| `Planner` | Task decomposition, risk tagging, routing |
| `Agents` | Agent worker lifecycle, sub-session management |
| `Memory` | Extraction, storage, retrieval, review |
| `Hosts` | Host registry, health checks, mTLS |
| `Tokens` | Usage tracking, cost calculation, budget alerts |
| `Telegram` | Bot process, thread mapping, voice transcription |
| `Skills` | Skill registry, versioning, conflict resolution |

## Zero-Install

```bash
cd backend
mix deps.get    # Fetch dependencies
mix compile     # Compile the project
mix ecto.setup  # Create, migrate, and seed the database
```

## Testing

```bash
mix test                # Run all tests
mix test --cover        # With coverage (target: 80%)
mix credo --strict      # Static analysis
mix format --check-formatted
```

## Internal Details

See `backend/spec/README.md` for schema design, GenServer supervision trees, and implementation notes.
