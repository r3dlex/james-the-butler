"""Shared test fixtures."""

from __future__ import annotations

import pytest
from pipeline_runner.stages.base import PipelineContext


@pytest.fixture
def pipeline_context() -> PipelineContext:
    return PipelineContext(pipeline_name="test-pipeline")
