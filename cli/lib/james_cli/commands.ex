defmodule JamesCli.Commands do
  @moduledoc """
  Dispatches parsed CLI args to the appropriate command handler.

  Returns `{:ok, output_string}` or `{:error, message}`.
  """

  alias JamesCli.{Auth, Client, Completions, Formatter}

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

  # --- Auth ---

  def dispatch(%{command: "login"}, config) do
    api_url = JamesCli.Config.get(config, ["server", "url"], "http://localhost:4000")

    case Auth.login_with_device_code(api_url) do
      {:ok, token} ->
        case Auth.save_token(token) do
          :ok ->
            {:ok, "Login successful. Token saved to #{Auth.token_path()}"}

          {:error, reason} ->
            {:error, "Login succeeded but could not save token: #{Exception.message(reason)}"}
        end

      {:error, msg} ->
        {:error, "Login failed: #{msg}"}
    end
  end

  def dispatch(%{command: "logout"}, _config) do
    case Auth.clear_token() do
      :ok -> {:ok, "Logged out. Token removed from #{Auth.token_path()}"}
      {:error, reason} -> {:error, "Logout failed: #{inspect(reason)}"}
    end
  end

  # --- Sessions ---

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

  def dispatch(%{command: "session", subcommand: "create", extras: extras, format: fmt}, config) do
    name = Map.get(extras, "name")
    session_type = Map.get(extras, "type", "chat")

    if is_nil(name) do
      {:error, "Usage: james session create --name <name> [--type chat|task]"}
    else
      attrs = %{"name" => name, "type" => session_type}

      case Client.create_session(config, attrs) do
        {:ok, session} -> {:ok, Formatter.format(session, fmt)}
        {:error, err} -> {:error, "Failed to create session: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "session", subcommand: "delete", extras: extras, format: _fmt}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james session delete --id <session_id>"}
    else
      case Client.delete_session(config, id) do
        {:ok, _} -> {:ok, "Session deleted"}
        {:error, err} -> {:error, "Failed to delete session: #{inspect(err)}"}
      end
    end
  end

  # --- Chat ---

  def dispatch(%{command: "chat", extras: extras, format: fmt}, config) do
    session_id = Map.get(extras, "session")
    message = Map.get(extras, "message") || Map.get(extras, "msg")

    with nil <- session_id,
         false <- is_nil(message) do
      case Client.chat(config, session_id, message) do
        {:ok, response} -> {:ok, Formatter.format(response, fmt)}
        {:error, err} -> {:error, "Chat failed: #{inspect(err)}"}
      end
    else
      nil ->
        {:error, "Usage: james chat --session <id> --message \"text\""}

      true ->
        {:error,
         "Interactive chat not yet implemented. Use --message \"text\" for single-shot chat."}
    end
  end

  # --- Tasks ---

  def dispatch(%{command: "task", subcommand: "list", extras: extras, format: fmt}, config) do
    session_id = Map.get(extras, "session")

    case Client.list_tasks(config, session_id) do
      {:ok, tasks} -> {:ok, Formatter.format(tasks, fmt)}
      {:error, err} -> {:error, "Failed to list tasks: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "task", subcommand: "show", extras: extras, format: fmt}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james task show --id <task_id>"}
    else
      case Client.get_task(config, id) do
        {:ok, task} -> {:ok, Formatter.format(task, fmt)}
        {:error, err} -> {:error, "Task not found: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "task", subcommand: "approve", extras: extras}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james task approve --id <task_id>"}
    else
      case Client.approve_task(config, id) do
        {:ok, _} -> {:ok, "Task #{id} approved"}
        {:error, err} -> {:error, "Failed to approve task: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "task", subcommand: "reject", extras: extras}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james task reject --id <task_id>"}
    else
      case Client.reject_task(config, id) do
        {:ok, _} -> {:ok, "Task #{id} rejected"}
        {:error, err} -> {:error, "Failed to reject task: #{inspect(err)}"}
      end
    end
  end

  # --- Projects ---

  def dispatch(%{command: "project", subcommand: "list", format: fmt}, config) do
    case Client.list_projects(config) do
      {:ok, projects} -> {:ok, Formatter.format(projects, fmt)}
      {:error, err} -> {:error, "Failed to list projects: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "project", subcommand: "show", extras: extras, format: fmt}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james project show --id <project_id>"}
    else
      case Client.get_project(config, id) do
        {:ok, project} -> {:ok, Formatter.format(project, fmt)}
        {:error, err} -> {:error, "Project not found: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "project", subcommand: "create", extras: extras, format: fmt}, config) do
    name = Map.get(extras, "name")

    if is_nil(name) do
      {:error, "Usage: james project create --name <name> [--description \"desc\"]"}
    else
      description = Map.get(extras, "description", "")
      attrs = %{"name" => name, "description" => description}

      case Client.create_project(config, attrs) do
        {:ok, project} -> {:ok, Formatter.format(project, fmt)}
        {:error, err} -> {:error, "Failed to create project: #{inspect(err)}"}
      end
    end
  end

  # --- Hooks ---

  def dispatch(%{command: "hook", subcommand: "list", format: fmt}, config) do
    case Client.list_hooks(config) do
      {:ok, hooks} -> {:ok, Formatter.format(hooks, fmt)}
      {:error, err} -> {:error, "Failed to list hooks: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "hook", subcommand: "show", extras: extras, format: fmt}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james hook show --id <hook_id>"}
    else
      case Client.get_hook(config, id) do
        {:ok, hook} -> {:ok, Formatter.format(hook, fmt)}
        {:error, err} -> {:error, "Hook not found: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "hook", subcommand: "create", extras: extras, format: fmt}, config) do
    name = Map.get(extras, "name")
    event = Map.get(extras, "event")
    action = Map.get(extras, "action")

    if is_nil(name) or is_nil(event) or is_nil(action) do
      {:error,
       "Usage: james hook create --name <n> --event <e> --action <a> [--command \"cmd\" --url \"url\"]"}
    else
      attrs =
        %{"name" => name, "event" => event, "action" => action}
        |> Map.put("command", Map.get(extras, "command"))
        |> Map.put("url", Map.get(extras, "url"))
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      case Client.create_hook(config, attrs) do
        {:ok, hook} -> {:ok, Formatter.format(hook, fmt)}
        {:error, err} -> {:error, "Failed to create hook: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "hook", subcommand: "delete", extras: extras}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james hook delete --id <hook_id>"}
    else
      case Client.delete_hook(config, id) do
        {:ok, _} -> {:ok, "Hook deleted"}
        {:error, err} -> {:error, "Failed to delete hook: #{inspect(err)}"}
      end
    end
  end

  # --- Skills ---

  def dispatch(%{command: "skill", subcommand: "list", format: fmt}, config) do
    case Client.list_skills(config) do
      {:ok, skills} -> {:ok, Formatter.format(skills, fmt)}
      {:error, err} -> {:error, "Failed to list skills: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "skill", subcommand: "create", extras: extras, format: fmt}, config) do
    name = Map.get(extras, "name")
    scope = Map.get(extras, "scope", "global")

    if is_nil(name) do
      {:error, "Usage: james skill create --name <name> [--scope global|user]"}
    else
      attrs = %{"name" => name, "scope" => scope}

      case Client.create_skill(config, attrs) do
        {:ok, skill} -> {:ok, Formatter.format(skill, fmt)}
        {:error, err} -> {:error, "Failed to create skill: #{inspect(err)}"}
      end
    end
  end

  def dispatch(%{command: "skill", subcommand: "delete", extras: extras}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james skill delete --id <skill_id>"}
    else
      case Client.delete_skill(config, id) do
        {:ok, _} -> {:ok, "Skill deleted"}
        {:error, err} -> {:error, "Failed to delete skill: #{inspect(err)}"}
      end
    end
  end

  # --- Memories ---

  def dispatch(%{command: "memory", subcommand: "list", format: fmt}, config) do
    case Client.list_memories(config) do
      {:ok, memories} -> {:ok, Formatter.format(memories, fmt)}
      {:error, err} -> {:error, "Failed to list memories: #{inspect(err)}"}
    end
  end

  # --- Hosts ---

  def dispatch(%{command: "host", subcommand: "list", format: fmt}, config) do
    case Client.list_hosts(config) do
      {:ok, hosts} -> {:ok, Formatter.format(hosts, fmt)}
      {:error, err} -> {:error, "Failed to list hosts: #{inspect(err)}"}
    end
  end

  def dispatch(%{command: "host", subcommand: "show", extras: extras, format: fmt}, config) do
    id = Map.get(extras, "id")

    if is_nil(id) do
      {:error, "Usage: james host show --id <host_id>"}
    else
      case Client.get_host(config, id) do
        {:ok, host} -> {:ok, Formatter.format(host, fmt)}
        {:error, err} -> {:error, "Host not found: #{inspect(err)}"}
      end
    end
  end

  # --- Catch-all ---

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

    Authentication:
      login                                Device code login (first time)
      logout                               Clear stored token

    Sessions:
      session list                         List all sessions
      session show --id <id>              Show a session
      session create --name <name> [--type chat|task]  Create a session
      session delete --id <id>           Delete a session

    Chat:
      chat --session <id> --message "msg"  Send a message (non-interactive)

    Tasks:
      task list [--session <id>]          List tasks
      task show --id <id>                 Show a task
      task approve --id <id>              Approve a task
      task reject --id <id>               Reject a task

    Projects:
      project list                         List projects
      project show --id <id>              Show a project
      project create --name <name> [--description "desc"]  Create a project

    Hooks:
      hook list                            List hooks
      hook show --id <id>                 Show a hook
      hook create --name <n> --event <e> --action <a> [--command "cmd" --url "url"]  Create a hook
      hook delete --id <id>               Delete a hook

    Skills:
      skill list                           List skills
      skill create --name <name> [--scope global|user]  Create a skill
      skill delete --id <id>              Delete a skill

    Memory & Hosts:
      memory list                          List memories
      host list                            List hosts
      host show --id <id>                 Show a host

    Other:
      completion bash|zsh|fish             Print shell completion script

    Global flags:
      --format json|stream_json|text       Output format (default: text)
      --non-interactive                    Headless/script mode
      --config <path>                     Custom config file
      --version                            Print version
      --help                               Print this help
    """
  end
end
