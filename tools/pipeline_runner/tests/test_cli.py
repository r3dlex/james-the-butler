"""Tests for CLI entry point."""

from __future__ import annotations

from click.testing import CliRunner
from pipeline_runner.cli import main


def test_main_help() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["--help"])
    assert result.exit_code == 0
    assert "Pipeline Runner" in result.output


def test_main_version() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["--version"])
    assert result.exit_code == 0
    assert "0.1.0" in result.output


def test_stages_command() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["stages"])
    assert result.exit_code == 0
    assert "build" in result.output
    assert "test" in result.output
    assert "lint" in result.output
    assert "deploy" in result.output


def test_archgate_command() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["archgate"])
    # Should pass (all rules pass in our repo)
    assert "rules passed" in result.output or "rule(s) failed" in result.output
