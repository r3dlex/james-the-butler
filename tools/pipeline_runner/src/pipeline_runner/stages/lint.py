"""Lint stage implementation."""

from __future__ import annotations

import logging
import subprocess

from pipeline_runner.stages.base import BaseStage, PipelineContext, StageResult

logger = logging.getLogger(__name__)


class LintStage(BaseStage):
    """Run linters and formatters across components."""

    name = "lint"

    def __init__(self, allow_failure: bool = False, **_kwargs: object) -> None:
        self.allow_failure = allow_failure

    def validate(self, context: PipelineContext) -> bool:
        return True

    def run(self, context: PipelineContext) -> StageResult:
        logs: list[str] = []
        try:
            result = subprocess.run(
                ["make", "lint"],
                capture_output=True,
                text=True,
                check=True,
            )
            logs.append(result.stdout)
            return StageResult(stage_name=self.name, success=True, logs=logs)
        except subprocess.CalledProcessError as exc:
            logs.append(exc.stderr)
            return StageResult(stage_name=self.name, success=False, logs=logs)
