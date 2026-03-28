# Frontend Specification (Vue 3)

## Purpose

The web frontend provides a responsive browser-based interface to James the Butler.

## Technology

- **Runtime**: Node.js 20+
- **Framework**: Vue 3 with Composition API (`<script setup>`)
- **Language**: TypeScript
- **Build**: Vite
- **State**: Pinia
- **Testing**: Vitest + Vue Test Utils
- **Linting**: ESLint + Prettier

## Key Features

- Dashboard with real-time updates via WebSocket
- Task management interface
- User settings and preferences
- Responsive layout (desktop + tablet)

## Zero-Install

```bash
cd frontend
npm ci          # Install exact dependency tree from lockfile
```

No global npm packages required. All tooling (Vite, ESLint, Vitest) is installed as devDependencies.

## API Integration

The frontend connects to the backend via:

- **REST**: Fetch/Axios for CRUD operations
- **WebSocket**: Phoenix channels client for real-time updates

## Testing

```bash
npm test        # Run Vitest suite
npm run lint    # ESLint + Prettier check
```

## Internal Details

See `frontend/spec/README.md` for component tree, routing, and store design.
