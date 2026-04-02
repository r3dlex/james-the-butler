# Frontend Internal Specification

## Project Structure

```
frontend/
├── src/
│   ├── assets/             # Static assets (logo, fonts)
│   ├── components/
│   │   ├── common/         # LoadingSpinner, ErrorBanner, etc.
│   │   ├── layout/         # AppSidebar, AppHeader, SidebarSection
│   │   ├── session/        # ChatInput, ChatMessage, PlannerStream, TaskList
│   │   ├── settings/       # ProviderCard, PersonalityEditor, etc.
│   │   └── ui/             # Generic primitives
│   ├── composables/
│   │   └── useProviderHeartbeat.ts
│   ├── lib/
│   │   ├── apiFetch.ts     # Typed fetch wrapper with error normalisation
│   │   └── sessionNames.ts # Auto-generated session name utilities
│   ├── pages/
│   │   ├── SessionView.vue     # Main chat page — FIFO queue, history, workspace panel
│   │   ├── DashboardPage.vue
│   │   ├── settings/
│   │   │   ├── SettingsModelsPage.vue  # Provider CRUD + OAuth PKCE flow
│   │   │   └── …
│   │   └── …
│   ├── router/             # Vue Router — route definitions and auth guard
│   ├── services/
│   │   ├── api.ts          # REST client (GET/POST/PUT/DELETE with JWT)
│   │   └── phoenix.ts      # Phoenix Socket factory
│   ├── stores/
│   │   ├── auth.ts         # JWT token, login/logout, current user
│   │   ├── messages.ts     # Per-session message list (setMessages, append, dedup)
│   │   ├── providers.ts    # Provider CRUD + startOAuthFlow / pollOAuthCompletion
│   │   ├── sessions.ts     # Session list, rename, execution mode, optimistic updates
│   │   └── socket.ts       # Phoenix Channel lifecycle (joinChannel with onJoin callback)
│   ├── types/              # TypeScript interfaces (Session, Message, Provider, …)
│   ├── App.vue
│   └── main.ts
├── src/__tests__/          # Vitest test files (co-located with src)
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
└── eslint.config.js
```

## Routing

| Route | Page | Description |
|-------|------|-------------|
| `/` | `DashboardPage` | Session list dashboard |
| `/sessions/:id` | `SessionView` | Active session chat view |
| `/settings/models` | `SettingsModelsPage` | Provider management |
| `/settings/…` | various | Personality, MCP, Skills, Auth, Billing, Directories |

## Stores (Pinia)

| Store | Key state / actions |
|-------|---------------------|
| `useAuthStore` | `currentUser`, `token`, `login`, `logout`, `fetchMe` |
| `useSessionStore` | `sessions`, `createSession`, `renameSession`, `updateExecutionMode` |
| `useMessageStore` | `messages` (per session), `setMessages`, `appendMessage` |
| `useSocketStore` | `joinChannel(topic, params, onJoin?)`, channel map |
| `useProviderStore` | `providers`, `addProvider`, `startOAuthFlow`, `pollOAuthCompletion` |

## Session View Architecture

```
SessionView
├── Loads history from channel join payload (onJoin callback)
├── Renders <ChatMessage> for each message
├── Tracks isStreaming (true while agent response streams)
├── sendQueue: ref<string[]> — FIFO queue for messages sent while streaming
├── watch(isStreaming) — drains sendQueue when streaming stops
└── Bottom panel:
    ├── <ChatInput> — textarea always enabled; emits "send"
    └── Workspace strip:
        ├── Working directory chips (session.workingDirectories)
        └── Execution mode selector → updateExecutionMode()
```

### Non-Blocking Message Queue

The `disabled` prop was removed from `ChatInput`. When the user sends a message while `isStreaming` is true:
1. An optimistic message is appended immediately to the message list.
2. The message text is pushed onto `sendQueue`.
3. When `isStreaming` transitions `true → false`, `watch(isStreaming)` calls `_doSend` with the next queued item.
4. Queue drains FIFO until empty.

### Chat History Persistence

`socket.ts joinChannel` accepts an optional `onJoin` callback:
```ts
socketStore.joinChannel(`session:${id}`, {}, (response) => {
  const msgs = response.messages as Array<...> | undefined;
  if (Array.isArray(msgs)) messageStore.setMessages(sessionId, normalize(msgs));
});
```
The backend `session_channel.ex` includes `%{messages: [...]}` in the join reply.

## Provider OAuth PKCE Flow (Frontend)

1. User selects OAuth-capable provider type (e.g. `openai_codex`).
2. Clicks **Connect via OAuth** → calls `providerStore.startOAuthFlow(type)`.
3. Response `{auth_url, state_key}` → `window.open(auth_url, "james_oauth", "width=600,height=700,…")`.
4. `waitForOAuthCompletion(stateKey)` polls `providerStore.pollOAuthCompletion` every 3 s.
5. On `status === "completed"`, the new provider is added to the store and the form resets.

## Testing Strategy

- Component tests: Vue Test Utils + Vitest, happy-dom environment
- Store tests: mock `services/api` module, no network
- Integration tests: full SessionView mount with mocked Phoenix channel
- Coverage target: ≥70% line coverage

## Key Conventions

- All components use `<script setup lang="ts">`
- Pinia stores use the composition-function form (`defineStore("id", () => { … })`)
- API errors are normalised via `toHumanError(e, fallback)` from `lib/apiFetch.ts`
- No `disabled` prop on `ChatInput` — UI never blocks message input
