"""Deploy stage implementation."""

from __future__ import annotations

import logging

from pipeline_runner.stages.base import BaseStage, PipelineContext, StageResult

logger = logging.getLogger(__name__)


class DeployStage(BaseStage):
    """Deploy to target environment."""

    name = "deploy"

    def __init__(
        self,
        environment: str = "staging",
        requires: list[str] | None = None,
        allow_failure: bool = False,
        **_kwargs: object,
    ) -> None:
        self.environment = environment
        self.requires = requires or []
        self.allow_failure = allow_failure

    def validate(self, context: PipelineContext) -> bool:
        for req in self.requires:
            result = context.results.get(req)
            if result is None or not result.success:
                logger.error("Required stage '%s' did not succeed", req)
                return False
        return True

    def run(self, context: PipelineContext) -> StageResult:
        logger.info("Deploying to %s", self.environment)
        # Deployment logic will be implemented per environment
        return StageResult(
            stage_name=self.name,
            success=True,
            message=f"Deployed to {self.environment}",
        )
