# Database Schema Reference

For the full platform specification, see [platform.md](platform.md) SS4.1.
For backend context details, see [elixir.md](elixir.md).

---

## Purpose

Defines the PostgreSQL schema managed by Ecto migrations. All tables use UUIDv7 primary keys and UTC timestamps unless noted otherwise.

## Extensions

| Extension | Purpose |
|-----------|---------|
| `pgvector` | Vector similarity search on memory embeddings |
| `citext` | Case-insensitive text for email fields |

---

## Tables

### users

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `name` | `text` | Display name |
| `email` | `citext` | Unique, not null |
| `oauth_provider` | `text` | `google`, `microsoft`, `github` |
| `oauth_uid` | `text` | Provider-specific user ID |
| `mfa_secret` | `text` | Encrypted TOTP secret |
| `mfa_method` | `text` | `totp` or `webauthn` |
| `personality_id` | `uuid` | FK to `personality_profiles` — account-level default |
| `execution_mode` | `text` | `direct` or `confirmed` — account-level default |
| `created_at` | `utc_datetime` | |
| `updated_at` | `utc_datetime` | |

### sessions

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `name` | `text` | User-assigned session name |
| `user_id` | `uuid` | FK to `users` |
| `host_id` | `uuid` | FK to `hosts` — assigned by meta-planner |
| `project_id` | `uuid` | FK to `projects`, nullable |
| `agent_type` | `text` | `chat`, `code`, `research`, `desktop`, `browser` |
| `personality_id` | `uuid` | FK to `personality_profiles`, nullable (inherits from project or user) |
| `execution_mode` | `text` | `direct` or `confirmed`, nullable (inherits) |
| `status` | `text` | `active`, `idle`, `archived` |
| `keep_intermediates` | `boolean` | Default `false` — retain working files after task completion |
| `created_at` | `utc_datetime` | |
| `updated_at` | `utc_datetime` | |
| `last_used_at` | `utc_datetime` | Updated on each message |

### messages

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `session_id` | `uuid` | FK to `sessions` |
| `role` | `text` | `user`, `assistant`, `system`, `planner` |
| `content` | `text` | Message body |
| `token_count` | `integer` | Tokens consumed by this message |
| `model` | `text` | Model used (e.g. `claude-sonnet-4-20250514`) |
| `created_at` | `utc_datetime` | |

### tasks

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `session_id` | `uuid` | FK to `sessions` |
| `parent_task_id` | `uuid` | FK to `tasks`, nullable — for sub-task hierarchy |
| `description` | `text` | Planner-generated task description |
| `risk_level` | `text` | `read_only`, `additive`, `destructive` |
| `status` | `text` | `pending`, `approved`, `running`, `completed`, `rejected`, `failed` |
| `host_id` | `uuid` | FK to `hosts` — where the task executes |
| `created_at` | `utc_datetime` | |
| `completed_at` | `utc_datetime` | Nullable |

### projects

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `name` | `text` | Project name |
| `user_id` | `uuid` | FK to `users` |
| `personality_id` | `uuid` | FK to `personality_profiles`, nullable |
| `execution_mode` | `text` | `direct` or `confirmed`, nullable |
| `created_at` | `utc_datetime` | |
| `updated_at` | `utc_datetime` | |

### hosts

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `name` | `text` | Host display name |
| `endpoint` | `text` | Host URL for mTLS connection |
| `status` | `text` | `online`, `offline`, `draining` |
| `is_primary` | `boolean` | Only one host is primary |
| `mtls_cert_fingerprint` | `text` | SHA-256 fingerprint for mutual TLS |
| `created_at` | `utc_datetime` | |
| `last_seen_at` | `utc_datetime` | Updated by health check heartbeat |

### memories

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `user_id` | `uuid` | FK to `users` |
| `content` | `text` | Extracted context |
| `embedding` | `vector(1536)` | pgvector embedding for similarity search |
| `source_session_id` | `uuid` | FK to `sessions` — where the memory was extracted from |
| `created_at` | `utc_datetime` | |

### token_ledger

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `session_id` | `uuid` | FK to `sessions` |
| `task_id` | `uuid` | FK to `tasks`, nullable |
| `model` | `text` | Model identifier |
| `input_tokens` | `integer` | |
| `output_tokens` | `integer` | |
| `cost_usd` | `decimal` | Computed cost at time of usage |
| `created_at` | `utc_datetime` | |

### skills

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `name` | `text` | Skill identifier |
| `content_hash` | `text` | SHA-256 of content for deduplication |
| `content` | `text` | Skill definition body |
| `scope` | `text` | `global`, `project`, `session` |
| `created_at` | `utc_datetime` | |
| `updated_at` | `utc_datetime` | |

### personality_profiles

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `name` | `text` | Profile name (e.g. "Formal", "Casual") |
| `user_id` | `uuid` | FK to `users` |
| `preset` | `text` | Built-in preset identifier, nullable |
| `custom_prompt` | `text` | User-defined system prompt override, nullable |
| `created_at` | `utc_datetime` | |

### mcp_configs

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `user_id` | `uuid` | FK to `users` |
| `name` | `text` | Config display name |
| `transport` | `text` | `stdio`, `sse`, `streamable_http` |
| `params` | `jsonb` | Transport-specific configuration |
| `created_at` | `utc_datetime` | |

### tab_groups

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `session_id` | `uuid` | FK to `sessions` |
| `chrome_group_id` | `integer` | Chrome tab group identifier |
| `color` | `text` | Tab group color |
| `tabs` | `jsonb` | Array of `{tab_id, url, title}` |
| `created_at` | `utc_datetime` | |
| `last_active_at` | `utc_datetime` | |

### artifacts

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `session_id` | `uuid` | FK to `sessions` |
| `task_id` | `uuid` | FK to `tasks`, nullable |
| `type` | `text` | `file`, `image`, `code`, `document` |
| `path` | `text` | File system path or object store key |
| `is_deliverable` | `boolean` | `true` = retained output, `false` = working file (cleaned up) |
| `created_at` | `utc_datetime` | |
| `cleaned_at` | `utc_datetime` | Nullable — set when working file is removed |

### execution_history

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `session_id` | `uuid` | FK to `sessions` |
| `structured_log` | `jsonb` | Machine-readable execution trace |
| `narrative_summary` | `text` | Human-readable summary generated by Oban job |
| `created_at` | `utc_datetime` | |

### telegram_threads

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | Primary key |
| `telegram_thread_id` | `bigint` | Telegram message thread ID |
| `session_id` | `uuid` | FK to `sessions` |
| `user_id` | `uuid` | FK to `users` |
| `created_at` | `utc_datetime` | |

---

## Indexes

| Table | Index | Type | Purpose |
|-------|-------|------|---------|
| `memories` | `memories_embedding_idx` | HNSW (`vector_cosine_ops`) | Approximate nearest neighbor search |
| `sessions` | `sessions_user_id_index` | B-tree | User session listing |
| `messages` | `messages_session_id_index` | B-tree | Session message history |
| `tasks` | `tasks_session_id_status_index` | B-tree composite | Task filtering by session and status |
| `token_ledger` | `token_ledger_session_id_index` | B-tree | Cost aggregation per session |
| `telegram_threads` | `telegram_threads_telegram_thread_id_index` | B-tree unique | Thread-to-session lookup |
