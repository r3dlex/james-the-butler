defmodule JamesCli.Completions do
  @moduledoc """
  Shell completion script generation for James CLI.

  Supports Bash, Zsh, and Fish shells.
  """

  @commands ~w[session chat skill memory host project task hook login logout completion version help tui]

  @subcommands %{
    "session" => ~w[list show create delete],
    "chat" => ~w[],
    "skill" => ~w[list create delete],
    "memory" => ~w[list],
    "host" => ~w[list show],
    "project" => ~w[list show create],
    "task" => ~w[list show approve reject],
    "hook" => ~w[list show create delete],
    "completion" => ~w[bash zsh fish]
  }

  @doc "Returns the top-level CLI command list."
  @spec commands() :: [String.t()]
  def commands, do: @commands

  @doc "Returns subcommands for the given top-level command."
  @spec subcommands(String.t()) :: [String.t()]
  def subcommands(command), do: Map.get(@subcommands, command, [])

  @doc "Generates a Bash completion script."
  @spec bash_script() :: String.t()
  def bash_script do
    commands_str = Enum.join(@commands, " ")

    subcommand_cases =
      @subcommands
      |> Enum.map_join("\n", fn {cmd, subs} ->
        "    #{cmd}) COMPREPLY=($(compgen -W \"#{Enum.join(subs, " ")}\" -- \"$cur\")) ;;"
      end)

    """
    _james_completions() {
      local cur prev
      cur="${COMP_WORDS[COMP_CWORD]}"
      prev="${COMP_WORDS[COMP_CWORD-1]}"

      if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "#{commands_str}" -- "$cur"))
        return 0
      fi

      case "$prev" in
    #{subcommand_cases}
        *) COMPREPLY=() ;;
      esac
    }

    complete -F _james_completions james
    """
  end

  @doc "Generates a Zsh completion script."
  @spec zsh_script() :: String.t()
  def zsh_script do
    commands_str = Enum.join(@commands, " ")

    """
    #compdef james

    _james() {
      local state

      _arguments \\
        '1: :->command' \\
        '*: :->args'

      case $state in
        command)
          _values 'command' #{commands_str}
          ;;
        args)
          case ${words[2]} in
    #{Enum.map_join(@subcommands, "\n", fn {cmd, subs} -> "        #{cmd}) _values 'subcommand' #{Enum.join(subs, " ")} ;;" end)}
          esac
          ;;
      esac
    }

    _james
    """
  end

  @doc "Generates a Fish completion script."
  @spec fish_script() :: String.t()
  def fish_script do
    command_completions =
      Enum.map_join(@commands, "\n", fn cmd ->
        "complete -c james -f -n '__fish_use_subcommand' -a #{cmd}"
      end)

    subcommand_completions =
      Enum.flat_map(@subcommands, fn {cmd, subs} ->
        Enum.map(subs, fn sub ->
          "complete -c james -f -n '__fish_seen_subcommand_from #{cmd}' -a #{sub}"
        end)
      end)
      |> Enum.join("\n")

    """
    # Fish completions for james CLI

    function __fish_use_subcommand
      set -l cmd (commandline -opc)
      test (count $cmd) -eq 1
    end

    #{command_completions}

    #{subcommand_completions}
    """
  end
end
