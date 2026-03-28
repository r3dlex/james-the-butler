# Pipeline Runner Specification (Python)

## Purpose

The pipeline runner orchestrates CI/CD pipelines for the project. It integrates with GitHub Actions and provides reusable pipeline stages.

## Technology

- **Runtime**: Python 3.12+
- **Package Manager**: Poetry (pyproject.toml)
- **Testing**: pytest
- **Linting**: ruff
- **Type Checking**: mypy

## Design

The pipeline runner is a CLI tool with a plugin-based stage architecture:

```
pipeline_runner/
├── cli.py          # CLI entry point (click)
├── pipeline.py     # Pipeline orchestration engine
├── stages/         # Built-in pipeline stages
│   ├── build.py
│   ├── test.py
│   ├── lint.py
│   └── deploy.py
└── github/         # GitHub Actions integration
    ├── client.py   # GitHub API client
    └── workflow.py # Workflow trigger/status helpers
```

## Pipeline Stages

| Stage    | Description                              |
|----------|------------------------------------------|
| `build`  | Compile/build all components             |
| `test`   | Run test suites across all components    |
| `lint`   | Run linters and formatters               |
| `deploy` | Deploy to target environment             |

## Zero-Install

```bash
cd tools/pipeline_runner
poetry install    # Create virtualenv and install all dependencies
```

No global pip packages required. Poetry manages the virtualenv automatically.

## GitHub Actions Integration

The pipeline runner is both:
1. **Called by** GitHub Actions workflows (as a step)
2. **Calls** the GitHub API to trigger workflows and check status

See `.github/workflows/` for workflow definitions.

## Testing

```bash
poetry run pytest                    # Run test suite
poetry run ruff check .              # Lint
poetry run ruff format --check .     # Format check
poetry run mypy src/                 # Type check
```

## Internal Details

See `tools/pipeline_runner/spec/README.md` for stage plugin API, configuration schema, and error handling.
