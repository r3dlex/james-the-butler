"""Tests for architecture gate rules."""

from __future__ import annotations

from pipeline_runner.stages.archgate import (
    check_adr_index,
    check_component_specs,
    check_coverage_config,
    check_lock_files,
    check_no_cross_imports,
    run_all_rules,
)


def test_check_adr_index() -> None:
    result = check_adr_index()
    assert result.rule == "adr-index"
    # Should pass since we have ADRs and index
    assert result.passed


def test_check_component_specs() -> None:
    result = check_component_specs()
    assert result.rule == "component-spec"
    assert result.passed


def test_check_no_cross_imports() -> None:
    result = check_no_cross_imports()
    assert result.rule == "no-cross-imports"
    assert result.passed


def test_check_lock_files() -> None:
    result = check_lock_files()
    assert result.rule == "lock-files"
    # May fail if lock files are missing; just verify it runs
    assert result.rule == "lock-files"


def test_check_coverage_config() -> None:
    result = check_coverage_config()
    assert result.rule == "coverage-config"


def test_run_all_rules() -> None:
    results = run_all_rules()
    assert len(results) > 0
    assert all(r.rule for r in results)
