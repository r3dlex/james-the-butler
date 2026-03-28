"""Tests for pipeline stage implementations."""

from __future__ import annotations

import subprocess
from unittest.mock import patch

from pipeline_runner.stages.base import PipelineContext, StageResult
from pipeline_runner.stages.build import BuildStage
from pipeline_runner.stages.deploy import DeployStage
from pipeline_runner.stages.lint import LintStage
from pipeline_runner.stages.test import TestStage


def _completed(stdout: str = "ok") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=[], returncode=0, stdout=stdout, stderr="")


def _failed(stderr: str = "error") -> subprocess.CalledProcessError:
    return subprocess.CalledProcessError(1, "make", stderr=stderr)


@patch("subprocess.run")
def test_build_stage_success(mock_run: object) -> None:
    mock_run.return_value = _completed()  # type: ignore[attr-defined]
    stage = BuildStage(components=["backend"])
    ctx = PipelineContext(pipeline_name="test")
    assert stage.validate(ctx)
    result = stage.run(ctx)
    assert result.success


@patch("subprocess.run")
def test_build_stage_failure(mock_run: object) -> None:
    mock_run.side_effect = _failed()  # type: ignore[attr-defined]
    stage = BuildStage(components=["backend"])
    ctx = PipelineContext(pipeline_name="test")
    result = stage.run(ctx)
    assert not result.success


@patch("subprocess.run")
def test_test_stage_success(mock_run: object) -> None:
    mock_run.return_value = _completed()  # type: ignore[attr-defined]
    stage = TestStage(components=["backend"])
    ctx = PipelineContext(pipeline_name="test")
    assert stage.validate(ctx)
    result = stage.run(ctx)
    assert result.success


@patch("subprocess.run")
def test_test_stage_failure(mock_run: object) -> None:
    mock_run.side_effect = _failed()  # type: ignore[attr-defined]
    stage = TestStage(components=["backend"])
    ctx = PipelineContext(pipeline_name="test")
    result = stage.run(ctx)
    assert not result.success


@patch("subprocess.run")
def test_lint_stage_success(mock_run: object) -> None:
    mock_run.return_value = _completed()  # type: ignore[attr-defined]
    stage = LintStage()
    ctx = PipelineContext(pipeline_name="test")
    assert stage.validate(ctx)
    result = stage.run(ctx)
    assert result.success


@patch("subprocess.run")
def test_lint_stage_failure(mock_run: object) -> None:
    mock_run.side_effect = _failed()  # type: ignore[attr-defined]
    stage = LintStage()
    ctx = PipelineContext(pipeline_name="test")
    result = stage.run(ctx)
    assert not result.success


def test_deploy_stage_success() -> None:
    stage = DeployStage(environment="staging", requires=[])
    ctx = PipelineContext(pipeline_name="test")
    assert stage.validate(ctx)
    result = stage.run(ctx)
    assert result.success
    assert "staging" in result.message


def test_deploy_stage_missing_requirement() -> None:
    stage = DeployStage(environment="staging", requires=["build"])
    ctx = PipelineContext(pipeline_name="test")
    assert not stage.validate(ctx)


def test_deploy_stage_failed_requirement() -> None:
    stage = DeployStage(environment="staging", requires=["build"])
    ctx = PipelineContext(pipeline_name="test")
    ctx.results["build"] = StageResult(stage_name="build", success=False)
    assert not stage.validate(ctx)


def test_deploy_stage_passed_requirement() -> None:
    stage = DeployStage(environment="staging", requires=["build"])
    ctx = PipelineContext(pipeline_name="test")
    ctx.results["build"] = StageResult(stage_name="build", success=True)
    assert stage.validate(ctx)
