# Mobile Internal Specification

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart              # App entry point
│   ├── app/
│   │   ├── app.dart           # MaterialApp / root widget
│   │   └── router.dart        # GoRouter configuration
│   ├── features/
│   │   ├── auth/              # Authentication feature
│   │   │   ├── data/          # Repositories, data sources
│   │   │   ├── domain/        # Models, use cases
│   │   │   └── presentation/  # Screens, widgets, providers
│   │   ├── dashboard/         # Dashboard feature
│   │   ├── tasks/             # Task management feature
│   │   └── settings/          # User preferences
│   ├── core/
│   │   ├── api/               # HTTP client, WebSocket
│   │   ├── theme/             # App theme definitions
│   │   └── utils/             # Shared utilities
│   └── providers/             # Top-level Riverpod providers
├── test/
│   ├── features/              # Feature-level tests
│   └── core/                  # Core utility tests
├── pubspec.yaml
├── analysis_options.yaml
└── l10n/                      # Localization files
```

## Navigation

Uses GoRouter for declarative routing:

| Route          | Screen             | Description          |
|----------------|--------------------|----------------------|
| `/`            | DashboardScreen    | Main dashboard       |
| `/tasks`       | TasksScreen        | Task list            |
| `/tasks/:id`   | TaskDetailScreen   | Single task view     |
| `/settings`    | SettingsScreen     | Preferences          |
| `/login`       | LoginScreen        | Authentication       |

## State Management (Riverpod)

| Provider           | Scope                                   |
|--------------------|-----------------------------------------|
| `authProvider`     | Auth state, JWT token                   |
| `tasksProvider`    | Task list, CRUD operations              |
| `socketProvider`   | WebSocket connection lifecycle          |
| `themeProvider`    | Light/dark mode preference              |

## Offline Support

- Local SQLite cache via drift
- Queue outbound mutations when offline
- Reconcile on reconnection with server-side timestamps

## Platform Considerations

- iOS: Cupertino adaptive widgets where appropriate
- Android: Material 3 theming
- Push notifications via Firebase Cloud Messaging (both platforms)

## Testing Strategy

- Unit tests for providers and domain logic
- Widget tests for screen components
- Integration tests for critical user flows
