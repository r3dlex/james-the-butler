# Backend Specification (Elixir/Phoenix)

## Purpose

The backend is the central API server. It owns all business logic, data persistence, and real-time communication.

## Technology

- **Runtime**: Elixir 1.16+ / OTP 26+
- **Framework**: Phoenix 1.7+
- **Database**: PostgreSQL 15+ via Ecto
- **Auth**: Token-based (Bearer JWT)

## API Surface

- `GET/POST/PUT/DELETE /api/*` — RESTful JSON endpoints
- `WS /socket` — Phoenix Channels for real-time events

## Contexts

The backend is organized into Phoenix contexts that encapsulate domain boundaries:

| Context        | Responsibility                        |
|----------------|---------------------------------------|
| `Accounts`     | User registration, authentication     |
| `Butler`       | Core assistant/butler logic           |
| `Notifications`| Push and in-app notification delivery |

## Zero-Install

```bash
cd backend
mix deps.get    # Fetch dependencies into _build/
mix compile     # Compile the project
mix ecto.setup  # Create, migrate, and seed the database
```

No global Hex archives or Mix archives required beyond a standard Elixir installation.

## Testing

```bash
mix test                # Run all tests
mix test --cover        # With coverage
mix credo --strict      # Static analysis
```

## Internal Details

See `backend/spec/README.md` for schema design, context boundaries, and implementation notes.
