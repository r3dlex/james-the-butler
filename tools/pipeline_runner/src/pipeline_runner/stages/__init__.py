"""Built-in pipeline stages."""

from __future__ import annotations

from typing import TYPE_CHECKING

from pipeline_runner.stages.build import BuildStage
from pipeline_runner.stages.deploy import DeployStage
from pipeline_runner.stages.lint import LintStage
from pipeline_runner.stages.test import TestStage

if TYPE_CHECKING:
    from pipeline_runner.stages.base import BaseStage

BUILTIN_STAGES: dict[str, type[BaseStage]] = {
    "build": BuildStage,
    "test": TestStage,
    "lint": LintStage,
    "deploy": DeployStage,
}
