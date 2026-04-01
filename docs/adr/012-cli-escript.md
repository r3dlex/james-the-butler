# ADR-012: CLI as Elixir escript

## Status

Accepted

## Context

Operators and power users need a command-line interface to interact with James
without a browser. The CLI must work headlessly (for scripting) and interactively
(REPL for chat). It must be a standalone binary requiring no Elixir runtime on
the target machine.

## Decision

Implement the CLI as an **Elixir escript** in `cli/` with its own `mix.exs`:

- **Standalone**: compiled to a single `james` binary via `mix escript.build`
- **Config**: reads `~/.james/config.toml` (TOML format via `:toml` library)
- **Output formats**: `text` (default), `json`, `stream_json` (newline-delimited)
- **Interactive mode**: REPL loop (`JamesCli.Repl`) for chat sessions
- **Headless mode**: `--non-interactive` for scripting and CI
- **Shell completions**: bash, zsh, fish scripts via `james completion <shell>`
- **Coverage**: 85% minimum via ExCoveralls

## Consequences

- **Positive**: Single binary distribution. Works without Elixir on target. 
  TOML config is human-friendly. Stream JSON enables Unix pipeline composition.
- **Negative**: Escript requires Erlang runtime (not truly standalone). Build step
  required before distribution. Limited interactive terminal features compared
  to a native CLI tool.

## Implementation Notes

- CLI is added as a new component in the archgate (`cli/spec/README.md` required).
- `JamesCli.Config.default_path/0` returns `~/.james/config.toml`.
- `JamesCli.Repl` accepts an `:io` option for test injection of stdin/stdout.
- All HTTP calls use `Req` with Bearer token auth from config.
- CI job: Elixir 1.18/OTP 27, `mix deps.get`, `mix compile`, `mix format --check-formatted`,
  `mix credo --strict`, `mix test --cover`.
