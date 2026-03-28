"""Tests for pipeline orchestration."""

from __future__ import annotations

from pipeline_runner.pipeline import Pipeline
from pipeline_runner.stages.base import BaseStage, PipelineContext, StageResult


class PassStage(BaseStage):
    name = "pass"

    def validate(self, context: PipelineContext) -> bool:
        return True

    def run(self, context: PipelineContext) -> StageResult:
        return StageResult(stage_name=self.name, success=True)


class FailStage(BaseStage):
    name = "fail"

    def validate(self, context: PipelineContext) -> bool:
        return True

    def run(self, context: PipelineContext) -> StageResult:
        return StageResult(stage_name=self.name, success=False, message="Intentional failure")


def test_pipeline_all_pass() -> None:
    pipeline = Pipeline(name="test", stages=[PassStage(), PassStage()])
    result = pipeline.execute()
    assert result.success
    assert len(result.stage_results) == 2


def test_pipeline_stops_on_failure() -> None:
    pipeline = Pipeline(name="test", stages=[FailStage(), PassStage()])
    result = pipeline.execute()
    assert not result.success
    assert len(result.stage_results) == 1


def test_pipeline_allow_failure_continues() -> None:
    fail_stage = FailStage()
    fail_stage.allow_failure = True
    pipeline = Pipeline(name="test", stages=[fail_stage, PassStage()])
    result = pipeline.execute()
    assert result.success
    assert len(result.stage_results) == 2
