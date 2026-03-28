# Pipeline Runner Internal Specification

## Project Structure

```
tools/pipeline_runner/
├── src/
│   └── pipeline_runner/
│       ├── __init__.py
│       ├── cli.py           # Click CLI entry point
│       ├── pipeline.py      # Pipeline orchestration engine
│       ├── config.py        # Configuration loading (YAML/TOML)
│       ├── stages/
│       │   ├── __init__.py
│       │   ├── base.py      # Abstract stage base class
│       │   ├── build.py     # Build stage implementation
│       │   ├── test.py      # Test stage implementation
│       │   ├── lint.py      # Lint stage implementation
│       │   └── deploy.py    # Deploy stage implementation
│       └── github/
│           ├── __init__.py
│           ├── client.py    # GitHub API client (PyGithub)
│           └── workflow.py  # Workflow dispatch and status
├── tests/
│   ├── __init__.py
│   ├── conftest.py          # Shared fixtures
│   ├── test_pipeline.py     # Pipeline orchestration tests
│   ├── test_stages.py       # Stage unit tests
│   └── test_github.py       # GitHub integration tests
├── pyproject.toml
└── poetry.lock
```

## Stage Plugin Architecture

All stages inherit from `BaseStage`:

```python
class BaseStage(ABC):
    name: str

    @abstractmethod
    def run(self, context: PipelineContext) -> StageResult:
        ...

    @abstractmethod
    def validate(self, context: PipelineContext) -> bool:
        ...
```

The pipeline engine runs stages sequentially, passing a shared `PipelineContext` that accumulates results. A stage failure halts the pipeline unless marked as `allow_failure`.

## Configuration

Pipelines are defined in YAML:

```yaml
pipeline:
  name: main
  stages:
    - build:
        components: [backend, frontend, mobile]
    - test:
        components: [backend, frontend, mobile]
        parallel: true
    - lint:
        allow_failure: true
    - deploy:
        environment: staging
        requires: [build, test]
```

## GitHub Actions Integration

- `client.py` wraps PyGithub for authenticated API access
- `workflow.py` can trigger workflow dispatches and poll for completion
- The runner itself is invoked from `.github/workflows/pipeline.yml`

## Error Handling

- Each stage returns a `StageResult` (success/failure + logs)
- Pipeline collects all results and produces a summary report
- Non-zero exit code if any required stage fails
- Structured logging via Python `logging` module
