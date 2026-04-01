# ADR-007: Test coverage targets

## Status

Accepted

## Context

Without explicit coverage targets, test coverage tends to degrade over time. We need enforceable minimums that balance quality with pragmatism across all four components.

## Decision

Enforce minimum test coverage thresholds in CI. Coverage checks are mandatory — builds fail if coverage drops below the target.

| Component       | Tool               | Minimum Coverage | Scope               |
|-----------------|--------------------|------------------|----------------------|
| Backend         | ExCoveralls / cover| 80%              | Line coverage        |
| Frontend        | Vitest (v8/istanbul)| 70%             | Line coverage        |
| Mobile          | flutter test --coverage | 70%         | Line coverage        |
| Pipeline Runner | pytest-cov         | 90%              | Line coverage        |

**Rationale for thresholds**:
- **Backend (80%)**: Core business logic; higher bar for server-side code handling data and auth.
- **Frontend (70%)**: UI code is harder to unit test meaningfully; some visual behavior is better validated manually or via E2E.
- **Mobile (70%)**: Same rationale as frontend; widget tests cover structure but not all interaction.
- **Pipeline Runner (90%)**: Small, critical tool with clear inputs/outputs; high coverage is achievable and important.

Coverage is checked per-component. No global aggregate target.

## Consequences

- **Positive**: Prevents coverage regression. Makes coverage expectations explicit. Catches untested code paths before merge.
- **Negative**: Coverage percentage can be gamed with low-value tests. Thresholds may need adjustment as codebase grows. Initial setup requires configuring coverage tools per component.

## Implementation Notes

- **Backend**: Uses Ecto Sandbox for DB-backed tests, ensuring test isolation with automatic rollback. `DataCase` and `ConnCase` test helpers are provided at `test/support/` for database and HTTP/channel tests respectively.
- **CI**: The backend CI pipeline includes a Postgres service container for integration tests.
