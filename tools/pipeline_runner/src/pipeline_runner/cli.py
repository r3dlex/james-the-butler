"""CLI entry point for the pipeline runner."""

import click

from pipeline_runner import __version__


@click.group()
@click.version_option(version=__version__)
def main() -> None:
    """James the Butler — Pipeline Runner."""


@main.command()
@click.argument("config_path", type=click.Path(exists=True))
def run(config_path: str) -> None:
    """Run a pipeline from a YAML configuration file."""
    from pipeline_runner.pipeline import Pipeline

    pipeline = Pipeline.from_config(config_path)
    result = pipeline.execute()
    raise SystemExit(0 if result.success else 1)


@main.command()
def stages() -> None:
    """List available pipeline stages."""
    from pipeline_runner.stages import BUILTIN_STAGES

    for name, stage_cls in BUILTIN_STAGES.items():
        click.echo(f"  {name}: {stage_cls.__doc__ or 'No description'}")


@main.command()
def archgate() -> None:
    """Run architecture gate checks."""
    from pipeline_runner.stages.archgate import run_all_rules

    results = run_all_rules()
    failed = [r for r in results if not r.passed]

    for r in results:
        status = click.style("PASS", fg="green") if r.passed else click.style("FAIL", fg="red")
        click.echo(f"  [{status}] {r.rule}: {r.message}")

    if failed:
        click.echo(f"\n{len(failed)} rule(s) failed.")
        raise SystemExit(1)
    else:
        click.echo(f"\nAll {len(results)} rules passed.")
