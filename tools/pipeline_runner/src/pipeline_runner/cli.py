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
