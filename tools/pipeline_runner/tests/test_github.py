"""Tests for GitHub integration modules."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from pipeline_runner.github.client import get_client
from pipeline_runner.github.workflow import get_workflow_status, trigger_workflow


@patch.dict("os.environ", {"GITHUB_TOKEN": "test-token"})
@patch("pipeline_runner.github.client.Github")
def test_get_client(mock_github: MagicMock) -> None:
    client = get_client()
    mock_github.assert_called_once()
    assert client is mock_github.return_value


@patch("pipeline_runner.github.client.Auth")
@patch("pipeline_runner.github.client.Github")
def test_get_client_no_token(mock_github: MagicMock, _mock_auth: MagicMock) -> None:
    with patch.dict("os.environ", {"GITHUB_TOKEN": ""}, clear=False):
        get_client()
        mock_github.assert_called_once()


def test_trigger_workflow() -> None:
    mock_client = MagicMock()
    mock_repo = MagicMock()
    mock_workflow = MagicMock()
    mock_client.get_repo.return_value = mock_repo
    mock_repo.get_workflow.return_value = mock_workflow
    mock_workflow.create_dispatch.return_value = True

    result = trigger_workflow(mock_client, "owner/repo", "ci.yml", ref="main")
    assert result is True
    mock_workflow.create_dispatch.assert_called_once_with(ref="main", inputs={})


def test_get_workflow_status_no_runs() -> None:
    mock_client = MagicMock()
    mock_repo = MagicMock()
    mock_workflow = MagicMock()
    mock_runs = MagicMock()
    mock_runs.totalCount = 0

    mock_client.get_repo.return_value = mock_repo
    mock_repo.get_workflow.return_value = mock_workflow
    mock_workflow.get_runs.return_value = mock_runs

    status = get_workflow_status(mock_client, "owner/repo", "ci.yml")
    assert status == "no_runs"


def test_get_workflow_status_with_runs() -> None:
    mock_client = MagicMock()
    mock_repo = MagicMock()
    mock_workflow = MagicMock()
    mock_run = MagicMock()
    mock_run.status = "completed"
    mock_runs = MagicMock()
    mock_runs.totalCount = 1
    mock_runs.__getitem__ = lambda self, i: mock_run

    mock_client.get_repo.return_value = mock_repo
    mock_repo.get_workflow.return_value = mock_workflow
    mock_workflow.get_runs.return_value = mock_runs

    status = get_workflow_status(mock_client, "owner/repo", "ci.yml")
    assert status == "completed"
