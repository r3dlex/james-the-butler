# James the Butler: Expanded Capabilities Implementation Plan

## Executive Summary

James already has solid foundations: 6 agent types, memory/pgvector, skills with SHA-256 versioning, filesystem watcher, GEPA evolution, hook dispatcher, and plugin schema. Four areas need implementation work:

1. **MCP Server Runtime** — Currently a UI exists (`SettingsMcpPage.vue`) but no backend runtime
2. **Skills Enhancement** — DB skills and watcher exist, but no Claude Code bidirectional bridge
3. **Hook Execution** — Dispatcher fires events but all handlers are stubs
4. **Plugin Runtime** — Schema exists but no actual lifecycle/sandbox/tool registration

---

## 1. MCP Server Runtime

### Current State
- **Frontend**: `SettingsMcpPage.vue` has UI for adding servers (name, transport: stdio|SSE|streamable_http)
- **Frontend store**: `settings.ts` calls `/api/settings/mcp_servers` (GET, POST, DELETE) — **no backend route exists**
- **Frontend type**: `McpServer { id, name, transport, status, isPreConfigured, params }`
- **No backend**: No schema, no context, no GenServer for MCP process management

### Database Changes
**New migration**: `backend/priv/repo/migrations/YYYYMMDDHHMMSS_create_mcp_servers.exs`

```elixir
create table(:mcp_servers) do
  add :user_id, references(:users, on_delete: :delete_all), null: false
  add :name, :string, null: false
  add :transport, :string, null: false  # "stdio" | "sse" | "streamable_http"
  add :command, :string  # for stdio: the spawn command
  add :url, :string      # for SSE/HTTP: the endpoint URL
  add :env, :map, default: %{}
  add :tools, :map, default: []  # cached list of exposed tools
  add :status, :string, default: "stopped"  # "stopped" | "running" | "error"
  timestamps(type: :utc_datetime)
end
create index(:mcp_servers, [:user_id])
```

### Architecture

```
James.MCP.ServerSupervisor (DynamicSupervisor)
  └── James.MCP.Server (GenServer, one per configured server)
        ├── stdio: Port-managed child process (Porcelain or raw Port)
        ├── SSE:  Mint HTTP client with SSE parsing
        └── streamable_http: Mint HTTP client with chunked reading
```

### New Backend Files

| File | Purpose | Complexity |
|------|---------|-----------|
| `backend/lib/james/mcp/server.ex` | GenServer: spawns/kills MCP process, handles JSON-RPC messages | Complex |
| `backend/lib/james/mcp/supervisor.ex` | DynamicSupervisor managing per-server GenServers | Medium |
| `backend/lib/james/mcp/client.ex` | JSON-RPC message builder/parser, tool exposure | Medium |
| `backend/lib/james/mcp/transports/stdio.ex` | Port-based stdio transport | Medium |
| `backend/lib/james/mcp/transports/sse.ex` | Mint + SSE event parsing | Medium |
| `backend/lib/james/mcp.ex` | Context module: CRUD for mcp_servers table | Simple |
| `backend/lib/james/mcp/server.ex` | Ecto schema | Simple |
| `backend/lib/james_web/controllers/mcp_server_controller.ex` | API endpoints for MCP CRUD | Simple |
| `backend/lib/james_web/router.ex` | Add route `resources "/settings/mcp-servers", McpServerController` | Simple |

### Key Implementation Details

**JSON-RPC Protocol** (all transports):
- Incoming: `{"jsonrpc": "2.0", "id": ..., "method": "tools/list", ...}`
- Outgoing: `{"jsonrpc": "2.0", "id": ..., "result": {"tools": [...]}}`
- James sends: `{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "...", "arguments": {...}}}`
- James receives: `{"jsonrpc": "2.0", "id": ..., "result": {"content": [...]}}`

**Transport Approach**:
- **stdio**: Use `Port` (built-in) or `Porcelain` library to spawn the MCP server process, send JSON-RPC via stdin, read from stdout. Recommended: use `make_port()` with `{port, [:stream, :binary, :exit_status]}` and read line-by-line.
- **SSE**: Use `Mint` (already a dependency via HTTP clients) to connect to SSE endpoint, parse `data:` lines as JSON-RPC events.
- **streamable_http**: Use `Mint` with chunked transfer encoding.

**Agent Tool Integration** (how agents call MCP tools):
- CodeAgent's `@tools` list should be extended to include MCP tools dynamically
- Add `James.Agents.Tools.McpTools` module that `list_mcp_tools/1` for a given session/user
- MCP tools follow this schema:
  ```elixir
  %{
    name: "mcp__server_name__tool_name",
    description: "...",
    input_schema: %{...}
  }
  ```
- When an agent calls an MCP tool, route to the correct `James.MCP.Server` GenServer via `:mcp_tool_call`

**Application Supervision Tree Change**:
In `backend/lib/james/application.ex`, add to `children_for_env`:
```elixir
James.MCP.Supervisor
```

### Files to Modify
- `backend/lib/james/application.ex` — add MCP.Supervisor to children
- `backend/lib/james_web/router.ex` — add MCP server API routes
- No changes needed to agents yet (MCP tool integration comes after runtime works)

### External Dependencies
- `mint` (verify it's available — it appears in deps)
- Consider adding `jason` for JSON parsing (already used in project)
- No new hex packages strictly required if using built-in `Port` and `Mint`

---

## 2. Skills Enhancement

### Current State
- **DB**: `skills` table (name, content_hash, content, scope) — SHA-256 content hashing
- **Filesystem watcher**: `James.Skills.Watcher` polls `.md` files every 5s, fires `config_change` hook on changes
- **GEPA evolution**: `ImprovementTrigger` + `SkillEvolutionWorker` for LLM-based skill improvement
- **Tool**: `James.Skills.SkillManage` provides `skill_manage` tool (list/show/create/update/delete)
- **Claude Code bridge**: `.claude/skills/dream.md` exists but is **not** integrated with James's DB skill system
- **Frontend UI**: `SettingsSkillsPage.vue` is empty stub ("skill system coming in future update")

### Goals
1. **Bidirectional sharing**: James skills ↔ Claude Code skills
2. **Skill templates**: Predefined skill structures users can instantiate
3. **Skill versioning/grooming**: Track skill history, deprecate/retire old skills

### New Backend Files

| File | Purpose | Complexity |
|------|---------|-----------|
| `backend/lib/james/skills/template.ex` | Schema for skill templates | Simple |
| `backend/lib/james/skills/version.ex` | Schema for skill version history | Simple |
| `backend/lib/james/skills/bridge.ex` | Claude Code skill import/export logic | Complex |
| `backend/lib/james/skills/groomer.ex` | Skill lifecycle management (deprecate, retire) | Medium |
| `backend/priv/repo/migrations/..._add_skills_templates_and_versions.exs` | New tables | Simple |
| `backend/lib/james_web/controllers/skill_controller.ex` | CRUD for skills (backend API) | Simple |

### Database Changes

```elixir
# Skill templates
create table(:skill_templates) do
  add :name, :string, null: false
  add :description, :text
  add :content_template, :text  # with {{placeholder}} syntax
  add :category, :string  # e.g., "memory", "code", "communication"
  add :variables, :map, default: []  # required variable definitions
  timestamps(type: :utc_datetime)
end

# Skill versions (append-only history)
create table(:skill_versions) do
  add :skill_id, references(:skills, on_delete: :delete_all), null: false
  add :content, :text, null: false
  add :content_hash, :string, null: false
  add :change_reason, :string
  add :evolved_by, :string  # "user" | "gepa" | "claude_code"
  timestamps(type: :utc_datetime)
end
```

### Bidirectional Bridge Architecture

The bridge operates as a **periodic sync + on-demand export**:

```
James.Skills.Bridge (GenServer)
  ├── James.Skills.Bridge.ClaudeCodeImporter  — reads .claude/skills/*.md → imports to DB
  └── James.Skills.Bridge.JamesExporter       — exports DB skills → .claude/skills/*.md
```

**Import (Claude Code → James)**:
- Triggered: On `config_change` hook from filesystem watcher, OR periodic sync
- Process: Read all `.md` files from `.claude/skills/`, parse frontmatter (`--- name: ... ---`), sync to DB via `Skills.sync_skill/2`
- The existing `Skills.sync_skill/2` already does hash-based change detection

**Export (James → Claude Code)**:
- Triggered: When a skill is created/updated in James DB
- Process: Write to `.claude/skills/{skill_name}.md` with frontmatter
- Uses the `.claude/skills/dir` configured in the project

**Conflict Resolution**:
- Prefer the newer content_hash
- Log conflicts but don't auto-delete
- User resolves via `skill_manage` tool or UI

### Skill Templates

Predefined templates users can instantiate:
- `memory-audit` — Phase-based memory review (similar to `dream.md`)
- `connection-check` — MCP/API connection verification
- `workspace-cleanup` — File hygiene maintenance
- `health-scan` — Dependency/quality checks

Template instantiation: `Skills.create_skill(%{name: "my-audit", content: interpolate(template.content_template, variables)})`

### Skill Grooming (`James.Skills.Groomer`)
- `deprecate_skill/1` — Mark skill as deprecated (adds frontmatter flag)
- `retire_skill/1` — Soft-delete (keeps version history)
- `suggest_grooming/1` — Analyze usage patterns, flag neglected/duplicate skills
- Called by `SkillEvolutionWorker` after GEPA evolution

### Files to Modify
- `backend/lib/james/skills.ex` — add `sync_skill_to_filesystem/1`, `import_from_claude_code/1`
- `backend/lib/james/application.ex` — start `James.Skills.Bridge` GenServer
- `frontend/src/pages/settings/SettingsSkillsPage.vue` — replace empty state with skill management UI

### External Dependencies
- None new required — uses existing filesystem + DB patterns

---

## 3. Hook Execution

### Current State
`James.Hooks.Dispatcher.execute_hook/2` has stub implementations:

```elixir
# ALL four are stubs:
defp execute_hook(%{type: "command"} = hook, _payload) do
  Logger.info("Hook #{hook.id}: executing command: #{command}")
  # Command execution would happen here in production
  :ok
end

defp execute_hook(%{type: "http"} = hook, payload) do
  Task.start(fn -> Req.post(url, json: payload) end)  # async but no result capture
  :ok
end

defp execute_hook(%{type: "prompt"} = hook, _payload) do
  if prompt != "", do: {:modify, %{inject_prompt: prompt}}, else: :ok
end

defp execute_hook(%{type: "agent"} = hook, _payload) do
  Logger.info("Hook #{hook.id}: agent dispatch")  # Agent hooks would spawn here
  :ok
end
```

### Hook Types to Implement

| Type | Input (from hook.config) | Behavior | Returns |
|------|-------------------------|----------|---------|
| `command` | `{command: string, timeout_ms: int}` | `System.cmd("sh", ["-c", command])` | `{:ok, stdout, exit_code}` or `{:error, reason}` |
| `http` | `{url: string, method: string, headers: map, body: map}` | `Req.request(method, url, ...)` | `{:ok, status, headers, body}` or `{:error, reason}` |
| `prompt` | `{prompt: string}` | Prepend to tool prompt | `{:modify, %{inject_prompt: string}}` |
| `agent` | `{agent_type: string, task: string}` | Spawn sub-agent via `OpenClaw.Supervisor` | `{:ok, task_id}` |

### Implementation Details

**Refactor Dispatcher** (`James.Hooks.Dispatcher`):

```elixir
# Add result timeout for async hooks
@hook_timeout 30_000  # 30 seconds

def fire(user_id, event, payload \\ %{}) do
  hooks = Hooks.list_hooks_for_event(user_id, event)

  if hooks == [] do
    :ok
  else
    hooks
    |> Enum.filter(&matches?(&1, payload))
    |> Enum.reduce(:ok, fn hook, acc ->
      merge_hook_result(execute_hook(hook, payload), acc)
    end)
  end
end

# Timeout wrapper for async-safe execution
defp execute_hook(hook, payload) do
  Task.Supervisor.async_nolink(James.TaskSupervisor, fn ->
    do_execute_hook(hook, payload)
  end)
  |> Task.await(@hook_timeout)
rescue
  e -> {:error, Exception.message(e)}
end

defp do_execute_hook(%{type: "command"} = hook, payload) do
  command = get_in(hook.config, ["command"]) || ""
  timeout = get_in(hook.config, ["timeout_ms"]) || 30_000

  if command != "" do
    {stdout, exit_code} = System.cmd("sh", ["-c", command], timeout: timeout)
    %{stdout: stdout, exit_code: exit_code}
  else
    {:error, "empty command"}
  end
end

defp do_execute_hook(%{type: "http"} = hook, payload) do
  url = get_in(hook.config, ["url"]) || ""
  method = String.to_upper(get_in(hook.config, ["method"]) || "POST")
  headers = get_in(hook.config, ["headers"]) || %{}
  body_key = get_in(hook.config, ["body_field"]) || "payload"

  if url != "" do
    req_body = Map.put(%{}, body_key, payload)

    case Req.request(method, url, json: req_body, headers: headers) do
      {:ok, %{status: status, headers: resp_headers, body: body}} ->
        %{status: status, body: body}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  else
    {:error, "empty URL"}
  end
end

defp do_execute_hook(%{type: "prompt"} = hook, _payload) do
  prompt = get_in(hook.config, ["prompt"]) || ""
  if prompt != "", do: {:modify, %{inject_prompt: prompt}}, else: :ok
end

defp do_execute_hook(%{type: "agent"} = hook, payload) do
  agent_type = get_in(hook.config, ["agent_type"]) || "chat"
  task = get_in(hook.config, ["task"]) || ""

  case start_hook_agent(agent_type, task, payload) do
    {:ok, task_id} -> %{task_id: task_id}
    {:error, reason} -> {:error, inspect(reason)}
  end
end

defp start_hook_agent(agent_type, task, payload) do
  attrs = %{
    user_id: payload.user_id,
    name: "hook-#{agent_type}-#{DateTime.utc_now()}",
    agent_type: agent_type
  }

  case Sessions.create_session(attrs) do
    {:ok, session} ->
      Sessions.create_message(%{session_id: session.id, role: "user", content: task})
      James.Planner.MetaPlanner.process_message(session.id, %{})
      {:ok, session.id}
    {:error, reason} ->
      {:error, reason}
  end
end
```

### Error Handling
- Command timeout: `System.cmd` accepts `:timeout` option — propagate as `{:error, :timeout}`
- HTTP failures: `Req` returns `{:error, reason}` — return `{:error, reason}`
- Agent failures: If `start_hook_agent` fails, return error tuple
- All errors are logged and returned but do NOT block the main agent flow (fire-and-forget for async events)

### Async vs Sync Hooks
- `pre_tool_use` and `pre_prompt_submit` are **synchronous** — must return within hook timeout
- `session_start`, `subagent_start`, etc. are **asynchronous** — fire and return `:ok` immediately
- The `merge_hook_result` function handles this: `command`/`http`/`agent` always return `:ok` for async events

### File to Modify
- `backend/lib/james/hooks/dispatcher.ex` — replace stub implementations

### External Dependencies
- None new (uses `Req` already in project, `Task.Supervisor.async_nolink` built-in)

---

## 4. Plugin Runtime

### Current State
- **Schema**: `plugins` table (name, version, manifest:map, enabled) — already exists
- **Registry**: `James.Plugins.Registry` — in-memory Agent with `register(plugin_id, manifest)`, `unregister(plugin_id)`, `list_all`, `skills_for_plugin`
- **Controller**: `PluginController` — CRUD (index, create, enable, disable, delete) — DB only, no actual installation
- **Problem**: `install_plugin` just inserts a DB record with empty manifest — no actual plugin code is ever loaded or executed

### Plugin Manifest Schema (what a real plugin provides)

```json
{
  "name": "example-plugin",
  "version": "0.1.0",
  "description": "An example plugin",
  "tools": [
    {
      "name": "example_tool",
      "description": "Does something",
      "input_schema": {
        "type": "object",
        "properties": {
          "arg": {"type": "string"}
        },
        "required": ["arg"]
      },
      "handler": "Elixir.MyPlugin.execute_tool"
    }
  ],
  "skills": [
    {"name": "example-skill", "content": "..."}
  ],
  "hooks": [
    {"event": "session_start", "handler": "Elixir.MyPlugin.on_session_start"}
  ],
  "permissions": ["filesystem:read", "http:GET"]
}
```

### Implementation Architecture

```
James.Plugins Supervisor (DynamicSupervisor)
  └── James.Plugins.Instance (GenServer, one per enabled plugin)
        ├── Loads plugin module (via Code.ensure_loaded)
        ├── Registers tools with James.Agents.Tools.Registry
        ├── Registers skills with James.Skills
        ├── Sets up hook handlers
        └── Manages plugin lifecycle (start/stop heartbeat)

James.Plugins.Loader (Module)
  └── Parses plugin manifest, validates permissions, loads code

James.Plugins.Sandbox (Module)
  └── Sandboxed execution using Elixir's built-in safety features
      - Code.compile_string restrictions
      - Process isolation via OTP supervision
      - Filesystem access via whitelist
```

### New Backend Files

| File | Purpose | Complexity |
|------|---------|-----------|
| `backend/lib/james/plugins/instance.ex` | GenServer: per-plugin lifecycle, tool registration | Complex |
| `backend/lib/james/plugins/loader.ex` | Manifest parsing, code loading, permission validation | Medium |
| `backend/lib/james/plugins/sandbox.ex` | Sandboxed execution environment | Complex |
| `backend/lib/james/plugins/tool_registry.ex` | Agent that tracks registered plugin tools | Medium |
| `backend/lib/james/plugins/hook_handler.ex` | Plugin hook handler registration | Medium |
| `backend/priv/repo/migrations/..._add_plugin_permissions_and_tools.exs` | Add fields to plugins table | Simple |

### Database Changes

```elixir
alter table(:plugins) do
  add :code_path, :string  # filesystem path to plugin code (optional)
  add :permissions, :map, default: []  # ["filesystem:read", "http:GET", etc.]
  add :installed_at, :utc_datetime
  add :last_active_at, :utc_datetime
end
```

### Installation Flow

```
1. PluginController.create(name, version)
   ↓
2. James.Plugins.install_plugin(attrs)
   → Insert DB record with manifest = %{}
   ↓
3. Plugin loader fetches plugin manifest (from registry or URL)
   → James.Plugins.Loader.load_manifest(plugin)
   → Update plugin record with parsed manifest + permissions
   ↓
4. When plugin is enabled:
   James.Plugins.enable_plugin(plugin)
   → James.Plugins.Instance.start_link(plugin_id)
   → Instance registers tools with James.Agents.Tools.Registry
   → Instance registers skills with James.Skills
   → Instance registers hook handlers with James.Hooks.Dispatcher
```

### Tool Registration Integration

Plugin tools should be exposed to agents via the same tool system used by CodeAgent:

```elixir
# James.Agents.Tools.Registry (new module)
defmodule James.Agents.Tools.Registry do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def register(tool_definition) do
    Agent.update(__MODULE__, &Map.put(&1, tool_definition.name, tool_definition))
  end

  def list_all(), do: Agent.get(__MODULE__, & &1)

  def get(name), do: Agent.get(__MODULE__, &Map.get(&1, name))
end

# James.Agents.CodeAgent — extend @tools:
defp get_all_tools(state) do
  base_tools = @tools  # existing built-in tools
  plugin_tools = James.Agents.Tools.Registry.list_all() |> Map.values()
  base_tools ++ plugin_tools
end
```

### Sandboxed Execution

Elixir/Erlang provides process isolation via OTP. For plugins:

1. **Code loading**: Only allow `Code.ensure_loaded/1` on approved modules — never `Code.eval_string`
2. **Process isolation**: Each plugin instance runs as its own GenServer — crashes don't propagate
3. **Filesystem sandbox**: Use `File.validate!/1` path restrictions in plugin tool implementations
4. **HTTP sandbox**: Plugins can only make HTTP calls to whitelisted domains (configured in permissions)

### Files to Modify

| File | Change | Complexity |
|------|--------|-----------|
| `backend/lib/james/plugins/plugin.ex` | Add code_path, permissions, installed_at, last_active_at fields | Simple |
| `backend/lib/james/application.ex` | Add `James.Plugins.Supervisor` to children | Simple |
| `backend/lib/james/agents/code_agent.ex` | Use `James.Agents.Tools.Registry` for dynamic tools | Medium |

### External Dependencies
- None new required — uses built-in OTP supervision, Code module

---

## 5. Implementation Sequencing

### Phase 1: MCP Server Runtime (Priority: HIGH)
Rationale: MCP is the most architecturally significant and most frontend-visible missing piece.

**Order**:
1. Database migration + schema + context module
2. `McpServerController` + router routes
3. `James.MCP.Supervisor` (DynamicSupervisor)
4. `James.MCP.Server` GenServer (stdio transport first — simplest)
5. Transport modules (SSE, streamable_http)
6. MCP tool exposure to CodeAgent

**Estimated complexity**: Complex
**Files created/modified**: ~10 new files + 3 modified

### Phase 2: Hook Execution (Priority: HIGH)
Rationale: Low-risk refactor of existing stubs; immediately useful for automation.

**Order**:
1. Implement `do_execute_hook` for all 4 types
2. Add timeout handling
3. Test each hook type

**Estimated complexity**: Medium
**Files created/modified**: 1 modified (`dispatcher.ex`)

### Phase 3: Plugin Runtime (Priority: MEDIUM)
Rationale: Depends on MCP runtime (plugin tools use similar patterns).

**Order**:
1. `James.Plugins.Instance` GenServer
2. `James.Plugins.ToolRegistry` Agent
3. Loader and sandbox modules
4. Database migration for new fields
5. Tool registry integration in CodeAgent

**Estimated complexity**: Complex
**Files created/modified**: ~7 new files + 3 modified

### Phase 4: Skills Enhancement (Priority: MEDIUM)
Rationale: Lower urgency; existing skill system works.

**Order**:
1. Database migrations (templates, versions)
2. `James.Skills.Bridge` GenServer
3. Import/export logic
4. Skill grooming
5. Frontend UI update

**Estimated complexity**: Medium
**Files created/modified**: ~6 new files + 3 modified

---

## 6. Cross-Cutting Concerns

### Error Handling Convention
All new GenServer/server modules should follow this pattern:
```elixir
defmodule Example do
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, state, {:continue, :setup}}
  end

  @impl true
  def handle_continue(:setup, state) do
    {:noreply, state}
  rescue
    e ->
      Logger.error("Example init failed: #{Exception.message(e)}")
      {:stop, :init_failure, state}
  end
end
```

### Logging Convention
- Use `require Logger` and `Logger.info/warning/error` consistently
- Include relevant IDs (hook_id, server_id, plugin_id) in log metadata
- Example: `Logger.info("MCP server started", server_id: server_id, transport: transport)`

### Testing Strategy
- Unit tests for each new module in `backend/test/james/`
- Integration tests for transport layer (mock MCP server)
- Frontend: add to existing test patterns in `frontend/src/__tests__/`

### Supervision Tree Summary

```
James.Supervisor
  ├── James.Repo
  ├── James.TaskSupervisor
  ├── James.PubSub
  ├── Oban
  ├── James.OpenClaw.Supervisor
  ├── James.OpenClaw.Orchestrator
  ├── James.Browser.CDPConnectionPool
  ├── James.Planner.MetaPlanner
  ├── James.Channels.TURNCredentials
  ├── James.Providers.ProviderOAuth
  ├── James.Plugins.Registry  (existing)
  ├── James.Plugins.Supervisor  (new)
  │     └── James.Plugins.Instance  (per enabled plugin)
  ├── James.MCP.Supervisor  (new)
  │     └── James.MCP.Server  (per configured server)
  ├── James.Skills.Bridge  (new)
  └── JamesWeb.Endpoint
```

---

## 7. Summary: Files and Complexity

### MCP Server Runtime
| File | Type | Complexity |
|------|------|-----------|
| `backend/priv/repo/migrations/..._create_mcp_servers.exs` | Migration | Simple |
| `backend/lib/james/mcp/server.ex` | Schema | Simple |
| `backend/lib/james/mcp.ex` | Context | Simple |
| `backend/lib/james/mcp/supervisor.ex` | DynamicSupervisor | Medium |
| `backend/lib/james/mcp/server/gen_server.ex` | GenServer | Complex |
| `backend/lib/james/mcp/transports/stdio.ex` | Transport | Medium |
| `backend/lib/james/mcp/transports/sse.ex` | Transport | Medium |
| `backend/lib/james/mcp/client.ex` | JSON-RPC | Medium |
| `backend/lib/james_web/controllers/mcp_server_controller.ex` | Controller | Simple |
| `backend/lib/james/application.ex` | Modify | Simple |
| `backend/lib/james_web/router.ex` | Modify | Simple |

### Hook Execution
| File | Type | Complexity |
|------|------|-----------|
| `backend/lib/james/hooks/dispatcher.ex` | Modify (replace stubs) | Medium |

### Plugin Runtime
| File | Type | Complexity |
|------|------|-----------|
| `backend/lib/james/plugins/instance.ex` | GenServer | Complex |
| `backend/lib/james/plugins/loader.ex` | Module | Medium |
| `backend/lib/james/plugins/sandbox.ex` | Module | Complex |
| `backend/lib/james/plugins/tool_registry.ex` | Agent | Medium |
| `backend/priv/repo/migrations/..._add_plugin_permissions.exs` | Migration | Simple |
| `backend/lib/james/application.ex` | Modify | Simple |
| `backend/lib/james/agents/code_agent.ex` | Modify | Medium |

### Skills Enhancement
| File | Type | Complexity |
|------|------|-----------|
| `backend/priv/repo/migrations/..._add_skill_templates_and_versions.exs` | Migration | Simple |
| `backend/lib/james/skills/template.ex` | Schema | Simple |
| `backend/lib/james/skills/version.ex` | Schema | Simple |
| `backend/lib/james/skills/bridge.ex` | GenServer | Complex |
| `backend/lib/james/skills/groomer.ex` | Module | Medium |
| `backend/lib/james/application.ex` | Modify | Simple |
| `frontend/src/pages/settings/SettingsSkillsPage.vue` | Modify | Simple |

---

## 8. External Dependencies Summary

| Dependency | Purpose | Required |
|-----------|---------|----------|
| `mint` | HTTP client (SSE/HTTP transport) | Already in deps |
| `req` | HTTP requests (hook HTTP type) | Already in deps |
| `jason` | JSON parsing | Already in deps |
| `porcelain` | stdio process management | Optional (can use built-in Port) |

No new production hex packages are strictly required.
