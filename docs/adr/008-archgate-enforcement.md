# ADR-008: Architecture gate enforcement

## Status

Accepted

## Context

Architectural decisions documented in ADRs are only useful if they are enforced. Without automated checks, drift from intended architecture is inevitable. We need a mechanism to validate architectural constraints as part of CI.

## Decision

Implement an **archgate** command in the pipeline runner that validates architectural rules on every PR. Archgate checks are CLI-based and run alongside lint and test in CI.

### Enforced rules

| Rule                     | Description                                         |
|--------------------------|-----------------------------------------------------|
| `adr-index`              | All ADR files are listed in `docs/adr/README.md`    |
| `component-spec`         | Each component has a `spec/README.md`               |
| `no-cross-imports`       | Components do not import from each other directly    |
| `lock-files`             | Lock files are committed for all components          |
| `coverage-config`        | Coverage thresholds are configured in each component |

### Integration

- `make archgate` runs all checks locally
- CI runs archgate as a separate job in the GitHub Actions pipeline
- The pipeline runner exposes `pipeline-runner archgate` as a CLI command
- Each rule is a function returning pass/fail with a human-readable message

### Extensibility

New rules are added as functions in `pipeline_runner/stages/archgate.py`. Each rule:
- Has a unique name
- Returns a `RuleResult` with pass/fail, rule name, and message
- Is registered in the `RULES` list

## Consequences

- **Positive**: Architectural constraints are enforced automatically. New contributors learn the rules through CI feedback. ADRs stay in sync with reality.
- **Negative**: Rules must be maintained as the architecture evolves. False positives require tuning. Adding new components requires updating archgate rules.
