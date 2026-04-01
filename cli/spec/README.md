# CLI Specification

The James CLI is an Elixir escript that provides both interactive REPL and
headless/non-interactive modes for interacting with the James server.

## Architecture

```
cli/
├── lib/james_cli/
│   ├── main.ex          # Escript entry point
│   ├── args.ex          # Argument parser
│   ├── config.ex        # ~/.james/config.toml loader
│   ├── commands.ex      # Command dispatcher
│   ├── client.ex        # HTTP API client
│   ├── formatter.ex     # Output formatter (json/stream_json/text)
│   ├── repl.ex          # Interactive REPL loop
│   └── completions.ex   # Shell completion scripts (bash/zsh/fish)
└── test/
    └── james_cli/
        ├── config_test.exs
        ├── args_test.exs
        ├── formatter_test.exs
        └── completions_test.exs
```

## Configuration

Configuration lives at `~/.james/config.toml`:

```toml
[server]
url = "http://localhost:4000"
token = "your-cli-token"

[output]
format = "text"   # json | stream_json | text
```

## Commands

| Command | Subcommand | Description |
|---------|-----------|-------------|
| `session` | `list\|show\|create\|archive` | Manage sessions |
| `chat` | — | Interactive REPL (or `--non-interactive`) |
| `skill` | `list\|show\|create\|update\|delete` | Manage skills |
| `memory` | `list\|search\|delete` | Manage memories |
| `host` | `list\|show\|register\|ping` | Manage hosts |
| `project` | `list\|show\|create` | Manage projects |
| `task` | `list\|show` | View tasks |
| `hook` | `list\|show\|create\|update\|delete\|enable\|disable` | Manage hooks |
| `completion` | `bash\|zsh\|fish` | Print shell completion script |

## Global Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--format json\|stream_json\|text` | Output format | `text` |
| `--non-interactive` | Headless/script mode | `false` |
| `--config <path>` | Custom config file | `~/.james/config.toml` |
| `--version` | Print version | — |
| `--help` | Print help | — |

## Shell Completions

```bash
# Bash
eval "$(james completion bash)"

# Zsh
eval "$(james completion zsh)"

# Fish
james completion fish | source
```

## Coverage Target

Minimum 85% line coverage enforced by ExCoveralls (see `mix.exs`).

## Design Decisions

- **No runtime deps on the server**: CLI is a standalone escript; all server
  interaction is via HTTP REST.
- **TDD**: All modules have corresponding test files written before implementation.
- **Injectable IO**: `Repl` accepts an `:io` option so tests can mock stdin/stdout.
- **Token auth**: Uses bcrypt-hashed CLI tokens stored in the server DB.
