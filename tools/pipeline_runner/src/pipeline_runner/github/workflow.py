"""GitHub Actions workflow helpers."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from github import Github

logger = logging.getLogger(__name__)


def trigger_workflow(
    client: Github,
    repo_name: str,
    workflow_id: str,
    ref: str = "main",
    inputs: dict[str, str] | None = None,
) -> bool:
    """Trigger a GitHub Actions workflow dispatch."""
    repo = client.get_repo(repo_name)
    workflow = repo.get_workflow(workflow_id)
    return workflow.create_dispatch(ref=ref, inputs=inputs or {})


def get_workflow_status(
    client: Github,
    repo_name: str,
    workflow_id: str,
    branch: str = "main",
) -> str:
    """Get the latest run status for a workflow on a branch."""
    repo = client.get_repo(repo_name)
    workflow = repo.get_workflow(workflow_id)
    runs = workflow.get_runs(branch=branch)
    if runs.totalCount == 0:
        return "no_runs"
    latest = runs[0]
    return str(latest.status)
