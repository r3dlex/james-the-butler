"""Test stage implementation."""

from __future__ import annotations

import logging
import subprocess

from pipeline_runner.stages.base import BaseStage, PipelineContext, StageResult

logger = logging.getLogger(__name__)


class TestStage(BaseStage):
    """Run test suites for project components."""

    name = "test"

    def __init__(
        self,
        components: list[str] | None = None,
        parallel: bool = False,
        allow_failure: bool = False,
        **_kwargs: object,
    ) -> None:
        self.components = components or ["backend", "frontend", "mobile"]
        self.parallel = parallel
        self.allow_failure = allow_failure

    def validate(self, context: PipelineContext) -> bool:
        return True

    def run(self, context: PipelineContext) -> StageResult:
        logs: list[str] = []
        for component in self.components:
            target = f"{component}-test"
            logger.info("Testing %s via make %s", component, target)
            try:
                result = subprocess.run(
                    ["make", target],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                logs.append(f"{component}: OK")
                logs.append(result.stdout)
            except subprocess.CalledProcessError as exc:
                logs.append(f"{component}: FAILED")
                logs.append(exc.stderr)
                return StageResult(stage_name=self.name, success=False, logs=logs)

        return StageResult(stage_name=self.name, success=True, logs=logs)
