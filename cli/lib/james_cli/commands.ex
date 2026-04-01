defmodule JamesCli.Commands do
  @moduledoc """
  Dispatches parsed CLI args to the appropriate command handler.

  Returns `{:ok, output_string}` or `{:error, message}`.
  """

  alias JamesCli.{Client, Completions, Formatter}

  @version "0.1.0"

  @doc "Dispatches to the appropriate handler based on parsed args."
  @spec dispatch(map(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def dispatch(%{version: true}, _config) do
    {:ok, "james version #{@version}"}
  end

  def dispatch(%{help: true}, _config) do
    {:ok, help_text()}
  end

  def dispatch(%{command: "completion", subcommand: shell}, _config) do
    script =
      case shell do
        "bash" -> Completions.bash_script()
        "zsh" -> Completions.zsh_script()
        "fish" -> Completions.fish_script()
        _ -> "Unknown shell '#{shell}'. Supported: bash, zsh, fish"
      end

    {:ok, script}
  end

  def dispatch(%{command: "session", subcommand: "list", format: fmt}, config) do
    case Client.list_sessions(config) do
      {:ok, sessions} -> {:ok, Formatter.format(sessions, fmt)}
      {:error, err} -> {:error, "Failed to list sessions: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "session", subcommand: "show", extras: extras, format: fmt}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james session show --id <session_id>"}
    else
      case Client.get_session(config, id) do
        {:ok, session} -> {:ok, Formatter.format(session, fmt)}
        {:error, err} -> {:error, "Session not found: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "skill", subcommand: "list", format: fmt}, config) do
    case Client.list_skills(config) do
      {:ok, skills} -> {:ok, Formatter.format(skills, fmt)}
      {:error, err} -> {:error, "Failed to list skills: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "memory", subcommand: "list", format: fmt}, config) do
    case Client.list_memories(config) do
      {:ok, memories} -> {:ok, Formatter.format(memories, fmt)}
      {:error, err} -> {:error, "Failed to list memories: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "host", subcommand: "list", format: fmt}, config) do
    case Client.list_hosts(config) do
      {:ok, hosts} -> {:ok, Formatter.format(hosts, fmt)}
      {:error, err} -> {:error, "Failed to list hosts: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: cmd, subcommand: sub}, _config) when not is_nil(cmd) do
    {:error, "Unknown command: #{cmd} #{sub || ""}. Run 'james --help' for usage."}
  end

  def dispatch(_args, _config) do
    {:ok, help_text()}
  end

  defp help_text do
    """
    James the Butler CLI v#{@version}

    Usage: james [options] <command> [subcommand] [flags]

    Commands:
      session list|show|create|archive   Manage sessions
      chat                               Interactive chat (REPL)
      skill list|show|create|update|delete  Manage skills
      memory list|search|delete          Manage memories
      host list|show|register|ping       Manage hosts
      project list|show|create           Manage projects
      task list|show                     View tasks
      hook list|show|create|update|delete|enable|disable  Manage hooks
      completion bash|zsh|fish           Print shell completion script

    Global flags:
      --format json|stream_json|text     Output format (default: text)
      --non-interactive                  Headless/script mode
      --config <path>                    Custom config file
      --version                          Print version
      --help                             Print this help
    """
  end
end
