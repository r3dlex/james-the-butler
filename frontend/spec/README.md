# Frontend Internal Specification

## Project Structure

```
frontend/
├── src/
│   ├── assets/          # Static assets (images, fonts)
│   ├── components/      # Reusable Vue components
│   │   ├── common/      # Shared UI primitives
│   │   └── layout/      # App shell, nav, sidebar
│   ├── composables/     # Composition API hooks
│   ├── pages/           # Route-level page components
│   ├── router/          # Vue Router configuration
│   ├── stores/          # Pinia stores
│   ├── services/        # API client and WebSocket
│   ├── types/           # TypeScript type definitions
│   ├── App.vue
│   └── main.ts
├── public/
├── test/
│   ├── components/      # Component tests
│   └── stores/          # Store tests
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
└── eslint.config.js
```

## Routing

| Route           | Page Component     | Description          |
|-----------------|--------------------|----------------------|
| `/`             | `DashboardPage`    | Main dashboard       |
| `/tasks`        | `TasksPage`        | Task list/management |
| `/settings`     | `SettingsPage`     | User preferences     |
| `/login`        | `LoginPage`        | Authentication       |

## Stores (Pinia)

| Store           | Responsibility                          |
|-----------------|-----------------------------------------|
| `useAuthStore`  | JWT token, login/logout, current user   |
| `useTaskStore`  | Task CRUD, optimistic updates           |
| `useSocketStore`| WebSocket connection lifecycle          |

## API Client

A typed API client in `services/api.ts` wraps fetch calls. WebSocket integration uses the Phoenix channels JS client.

## Testing Strategy

- Component tests with Vue Test Utils + Vitest
- Store tests in isolation (mock API calls)
- No E2E tests at this level (handled at integration layer)
