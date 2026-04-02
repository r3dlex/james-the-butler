# Backend Internal Specification

## Project Structure

```
backend/
├── config/
│   ├── config.exs          # Base config (OTel, Oban, Phoenix, JWT secret)
│   ├── dev.exs             # Dev overrides (DB, CORS, secret_key_base)
│   ├── prod.exs            # Production overrides
│   └── test.exs            # Test overrides
├── lib/
│   ├── james/              # Business-logic contexts
│   │   ├── accounts/       # User registration, JWT, MFA
│   │   ├── agents/         # Agent worker GenServers (chat, code, research, desktop, browser, security)
│   │   ├── artifacts/      # Output artifact management and narrative summaries
│   │   ├── auth/           # JWT generation/verification, device code flow, OAuth helpers
│   │   ├── browser/        # CDP Chrome lifecycle, tab groups, crash recovery
│   │   ├── channels/       # Phoenix PubSub event bus and Telegram bot
│   │   ├── commands/       # Slash-command processor
│   │   ├── compaction/     # Conversation microcompaction
│   │   ├── cron/           # Cron expression parser and scheduler
│   │   ├── desktop/        # Desktop control daemon protocol and agent
│   │   ├── embeddings/     # Vector embedding generation
│   │   ├── execution_mode/ # Direct/Confirmed mode cascade
│   │   ├── hooks/          # Event-driven hook dispatcher
│   │   ├── hosts/          # Host registry and health checks
│   │   ├── llm_provider/   # LLM provider adapter (selects configured backend)
│   │   ├── memories/       # Memory extraction, storage, retrieval
│   │   ├── open_claw/      # OpenClaw orchestrator and supervisor
│   │   ├── personality/    # Personality presets and custom profiles
│   │   ├── planner/        # MetaPlanner GenServer, risk classifier
│   │   ├── plugins/        # Plugin registry
│   │   ├── provider_settings/ # Provider config CRUD, model catalog
│   │   ├── providers/      # LLM provider adapters (Anthropic, OpenAI, Gemini, MiniMax, …)
│   │   │   └── provider_oauth.ex  # PKCE OAuth flow GenServer for provider credential connections
│   │   ├── search/         # Hybrid full-text + vector search
│   │   ├── sessions/       # Session CRUD, message persistence, away detector
│   │   ├── skills/         # Skill registry, versioning, watcher
│   │   ├── tasks/          # Task lifecycle (approval, rejection, risk levels)
│   │   ├── telemetry.ex    # OpenTelemetry setup and span helpers
│   │   └── tokens/         # Token usage tracking and cost calculation
│   ├── james_web/          # Phoenix web layer
│   │   ├── channels/       # session_channel, planner_channel, host_channel
│   │   ├── controllers/    # REST controllers (see API spec)
│   │   │   └── provider_oauth_controller.ex  # OAuth start/callback/status
│   │   ├── plugs/          # Auth plug (JWT verification)
│   │   └── router.ex       # Route definitions
│   └── james/
│       └── application.ex  # OTP Application — supervision tree, Telemetry.setup()
├── priv/repo/
│   ├── migrations/         # Ecto migrations (PostgreSQL + pgvector)
│   └── seeds.exs
├── test/
│   ├── james/              # Context unit tests
│   ├── james_web/          # Controller and channel integration tests
│   └── support/            # ConnCase, DataCase, channel helpers
├── mix.exs                 # Dependencies including OpenTelemetry suite
└── mix.lock
```

## Supervision Tree (non-test)

```
James.Supervisor (one_for_one)
├── James.Repo
├── Phoenix.PubSub (James.PubSub)
├── Oban
├── James.OpenClaw.Supervisor
│   └── James.OpenClaw.Orchestrator
├── James.Planner.MetaPlanner        — decomposes messages into tasks
├── James.Providers.ProviderOAuth    — PKCE OAuth flow state (ETS)
├── James.Plugins.Registry
└── JamesWeb.Endpoint
```

## Key GenServer Designs

### MetaPlanner

- Receives `{:send_message, session, message}` calls
- Calls `LLMProvider.configured().send_message/2` with a decomposition prompt
- **Critical**: `message.content` must be extracted before string concatenation (struct `<>` raises `ArgumentError`)
- Risk levels: `:read_only`, `:additive`, `:destructive`
- Broadcasts task list updates via Phoenix PubSub

### ProviderOAuth

- Named ETS table: `:provider_oauth_states`
- Entry shape: `%{provider_type, user_id, verifier, redirect_uri, expires_at, status, provider}`
- Sweep timer: every 60 seconds, deletes entries where `expires_at < now`
- PKCE: SHA-256 hash of the verifier, base64-url-encoded (no padding)

## Contexts

| Context | Key modules |
|---------|------------|
| `Accounts` | `User`, `Accounts` |
| `Sessions` | `Session`, `Message`, `Sessions`, `SessionChannel` |
| `Planner` | `MetaPlanner`, `RiskClassifier` |
| `Providers` | `Anthropic`, `OpenAI`, `Gemini`, `MiniMax`, `ProviderOAuth` |
| `ProviderSettings` | `ProviderConfig`, `ModelCatalog` |
| `Agents` | `ChatAgent`, `CodeAgent`, `ResearchAgent`, `DesktopAgent`, `BrowserAgent`, `SecurityAgent` |
| `Memory` | `Memory`, `DynamicRetriever`, workers |
| `Hosts` | `Host`, `Cluster` |
| `Tokens` | `TokenLedger` |
| `Skills` | `Registry`, `Watcher` |

## OpenTelemetry

- Dependencies: `opentelemetry_api`, `opentelemetry`, `opentelemetry_exporter`, `opentelemetry_phoenix`, `opentelemetry_ecto`, `opentelemetry_oban`
- `James.Telemetry.setup/0` called in `Application.start/2` (non-test)
- OTLP endpoint: env var `OTEL_EXPORTER_OTLP_ENDPOINT` (default `http://localhost:4318`)
- Custom spans: `James.Telemetry.with_span("name", %{attr: val}, fn -> ... end)`

## Testing Strategy

- Context unit tests: isolated, mock HTTP providers via `Bypass`
- Controller tests: `ConnCase` with real DB (Ecto sandbox)
- Channel tests: Phoenix channel test helpers
- GenServer tests: `start_supervised!` for named servers; `async: false` when sharing ETS tables
- Coverage target: ≥50% line coverage (threshold checked in CI)
