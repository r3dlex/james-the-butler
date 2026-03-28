# Backend Internal Specification

## Project Structure

```
backend/
├── config/              # Environment-specific configuration
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── test.exs
├── lib/
│   ├── james/           # Business logic (contexts)
│   │   ├── accounts/    # User management context
│   │   ├── butler/      # Core butler logic context
│   │   └── notifications/ # Notification delivery context
│   ├── james_web/       # Web layer
│   │   ├── controllers/ # REST API controllers
│   │   ├── channels/    # Phoenix channels (WebSocket)
│   │   └── router.ex
│   └── james.ex         # Application entry point
├── priv/
│   └── repo/
│       ├── migrations/  # Ecto migrations
│       └── seeds.exs    # Seed data
├── test/
│   ├── james/           # Context tests
│   ├── james_web/       # Controller/channel tests
│   └── test_helper.exs
├── mix.exs
└── mix.lock
```

## Contexts

### Accounts
- User registration and profile management
- Token-based authentication (JWT)
- Password hashing via Argon2

### Butler
- Core assistant task logic
- Task creation, scheduling, and completion
- Event sourcing for task state transitions

### Notifications
- In-app notification storage and delivery
- Push notification dispatch (APNS/FCM)
- WebSocket broadcast via Phoenix Channels

## Database Schema

Key tables (defined via Ecto migrations):

- `users` — id, email, hashed_password, inserted_at, updated_at
- `tasks` — id, user_id, title, description, status, due_at, inserted_at, updated_at
- `notifications` — id, user_id, type, payload, read_at, inserted_at

## Testing Strategy

- Unit tests for context functions (isolated, no HTTP)
- Integration tests for controllers (ConnTest)
- Channel tests for real-time features
- Factory-based test data via ExMachina
