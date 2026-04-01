"""Tests for architecture gate rules."""

from __future__ import annotations

from unittest.mock import patch

from pipeline_runner.stages.archgate import (
    check_adr_index,
    check_component_specs,
    check_coverage_config,
    check_lock_files,
    check_no_cross_imports,
    run_all_rules,
)


def test_check_adr_index_passes() -> None:
    result = check_adr_index()
    assert result.rule == "adr-index"
    assert result.passed


def test_check_adr_index_missing_index(tmp_path: object) -> None:
    with patch("pipeline_runner.stages.archgate.PROJECT_ROOT", tmp_path):
        result = check_adr_index()
        assert not result.passed
        assert "not found" in result.message


def test_check_adr_index_missing_entry(tmp_path: object) -> None:
    adr_dir = tmp_path / "docs" / "adr"
    adr_dir.mkdir(parents=True)
    (adr_dir / "README.md").write_text("# Index\n")
    (adr_dir / "001-test.md").write_text("# ADR 001\n")
    with patch("pipeline_runner.stages.archgate.PROJECT_ROOT", tmp_path):
        result = check_adr_index()
        assert not result.passed
        assert "001-test.md" in result.message


def test_check_component_specs_passes() -> None:
    result = check_component_specs()
    assert result.rule == "component-spec"
    assert result.passed


def test_check_component_specs_missing(tmp_path: object) -> None:
    components = {"missing": tmp_path / "missing"}
    with patch("pipeline_runner.stages.archgate.COMPONENTS", components):
        result = check_component_specs()
        assert not result.passed
        assert "missing" in result.message


def test_check_no_cross_imports_passes() -> None:
    result = check_no_cross_imports()
    assert result.rule == "no-cross-imports"
    assert result.passed


def test_check_no_cross_imports_violation(tmp_path: object) -> None:
    comp_a = tmp_path / "a"
    comp_b = tmp_path / "b"
    comp_a.mkdir()
    comp_b.mkdir()
    (comp_a / "main.py").write_text("from '../b/module' import foo\n")
    components = {"a": comp_a, "b": comp_b}
    with (
        patch("pipeline_runner.stages.archgate.COMPONENTS", components),
        patch("pipeline_runner.stages.archgate.PROJECT_ROOT", tmp_path),
    ):
        result = check_no_cross_imports()
        assert result.rule == "no-cross-imports"


def test_check_lock_files_all_present() -> None:
    result = check_lock_files()
    assert result.rule == "lock-files"
    # Passes with warning even if some are missing
    assert result.passed


def test_check_lock_files_missing(tmp_path: object) -> None:
    components = {"test": tmp_path / "test"}
    lock_files = {"test": "test.lock"}
    (tmp_path / "test").mkdir()
    with (
        patch("pipeline_runner.stages.archgate.COMPONENTS", components),
        patch("pipeline_runner.stages.archgate.LOCK_FILES", lock_files),
    ):
        result = check_lock_files()
        assert result.passed  # Warning, not failure
        assert "Warning" in result.message


def test_check_coverage_config() -> None:
    result = check_coverage_config()
    assert result.rule == "coverage-config"
    assert result.passed


def test_check_coverage_config_missing(tmp_path: object) -> None:
    components = {
        "backend": tmp_path / "backend",
        "frontend": tmp_path / "frontend",
        "pipeline_runner": tmp_path / "pipeline_runner",
        "cli": tmp_path / "cli",
    }
    for p in components.values():
        p.mkdir(parents=True)
    # Create files without coverage config
    (components["backend"] / "mix.exs").write_text("defmodule Mix do end\n")
    (components["frontend"] / "vite.config.ts").write_text("export default {}\n")
    (components["pipeline_runner"] / "pyproject.toml").write_text("[tool]\n")
    (components["cli"] / "mix.exs").write_text("defmodule Mix do end\n")
    with patch("pipeline_runner.stages.archgate.COMPONENTS", components):
        result = check_coverage_config()
        assert not result.passed


def test_run_all_rules() -> None:
    results = run_all_rules()
    assert len(results) == 5
    assert all(r.rule for r in results)
