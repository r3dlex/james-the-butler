"""Base stage abstraction."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class PipelineContext:
    """Shared context passed through pipeline stages."""

    pipeline_name: str
    results: dict[str, StageResult] = field(default_factory=dict)
    env: dict[str, str] = field(default_factory=dict)


@dataclass
class StageResult:
    """Result of a single stage execution."""

    stage_name: str
    success: bool
    message: str = ""
    logs: list[str] = field(default_factory=list)


class BaseStage(ABC):
    """Abstract base class for pipeline stages."""

    name: str
    allow_failure: bool = False

    @abstractmethod
    def run(self, context: PipelineContext) -> StageResult:
        """Execute the stage."""
        ...

    @abstractmethod
    def validate(self, context: PipelineContext) -> bool:
        """Validate that the stage can run given current context."""
        ...
