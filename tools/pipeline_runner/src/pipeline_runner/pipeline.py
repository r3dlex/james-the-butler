"""Pipeline orchestration engine."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from pipeline_runner.stages import BUILTIN_STAGES
from pipeline_runner.stages.base import BaseStage, PipelineContext, StageResult

logger = logging.getLogger(__name__)


@dataclass
class PipelineResult:
    """Aggregate result of a pipeline run."""

    success: bool
    stage_results: list[StageResult] = field(default_factory=list)


class Pipeline:
    """Orchestrates a sequence of pipeline stages."""

    def __init__(self, name: str, stages: list[BaseStage]) -> None:
        self.name = name
        self.stages = stages

    @classmethod
    def from_config(cls, config_path: str) -> Pipeline:
        """Load a pipeline from a YAML configuration file."""
        path = Path(config_path)
        with path.open() as f:
            data: dict[str, Any] = yaml.safe_load(f)

        pipeline_config = data["pipeline"]
        name: str = pipeline_config["name"]
        stages: list[BaseStage] = []

        for stage_def in pipeline_config["stages"]:
            if isinstance(stage_def, str):
                stage_name = stage_def
                stage_config: dict[str, Any] = {}
            else:
                stage_name = next(iter(stage_def))
                stage_config = stage_def[stage_name] or {}

            stage_cls = BUILTIN_STAGES[stage_name]
            stages.append(stage_cls(**stage_config))

        return cls(name=name, stages=stages)

    def execute(self) -> PipelineResult:
        """Run all stages in sequence."""
        context = PipelineContext(pipeline_name=self.name)
        results: list[StageResult] = []
        success = True

        for stage in self.stages:
            logger.info("Running stage: %s", stage.name)

            if not stage.validate(context):
                logger.error("Stage validation failed: %s", stage.name)
                result = StageResult(
                    stage_name=stage.name, success=False, message="Validation failed"
                )
            else:
                result = stage.run(context)

            results.append(result)
            context.results[stage.name] = result

            if not result.success and not stage.allow_failure:
                logger.error("Stage failed: %s", stage.name)
                success = False
                break

        return PipelineResult(success=success, stage_results=results)
