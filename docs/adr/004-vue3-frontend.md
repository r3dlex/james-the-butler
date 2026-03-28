# ADR-004: Vue 3 for frontend

## Status

Accepted

## Context

The web frontend needs a reactive UI framework that supports TypeScript, has good tooling, and can efficiently handle real-time data updates.

## Decision

Use **Vue 3** with the **Composition API** (`<script setup>`) and **TypeScript** throughout.

Key technology choices:
- **Vite** for build tooling (fast HMR, ESM-native)
- **Pinia** for state management
- **Vue Router** for client-side routing
- **Vitest** for unit testing (Vite-native test runner)
- **ESLint + Prettier** for code quality and formatting

## Consequences

- **Positive**: Composition API enables better TypeScript integration and code reuse. Vite provides fast development feedback. Pinia is simpler than Vuex. Vue's template syntax is approachable for new contributors.
- **Negative**: Vue ecosystem is smaller than React's. Some third-party component libraries lag behind React equivalents. Composition API has a learning curve for developers familiar with Options API.
