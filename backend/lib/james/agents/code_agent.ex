defmodule James.Agents.CodeAgent do
  @moduledoc """
  Agent that can read/write files, execute shell commands, and interact with code.
  Extends the base chat agent pattern with tool use capabilities.

  Runs an agentic loop: calls the Anthropic API with tool definitions, executes any
  tool_use blocks returned by the model, feeds results back, and repeats until the
  model stops requesting tools or the maximum iteration count is reached.
  """

  use GenServer, restart: :temporary

  alias James.Providers.Anthropic
  alias James.{Sessions, Tasks, Tokens}

  defstruct [:session_id, :task_id, :messages, :system_prompt, :model, :working_dirs]

  @max_iterations 10

  @tools [
    %{
      name: "read_file",
      description: "Read the contents of a file at the given path.",
      input_schema: %{
        type: "object",
        properties: %{path: %{type: "string", description: "File path to read"}},
        required: ["path"]
      }
    },
    %{
      name: "write_file",
      description: "Write content to a file, creating it if it doesn't exist.",
      input_schema: %{
        type: "object",
        properties: %{
          path: %{type: "string", description: "File path to write"},
          content: %{type: "string", description: "Content to write"}
        },
        required: ["path", "content"]
      }
    },
    %{
      name: "list_directory",
      description: "List files and directories at the given path.",
      input_schema: %{
        type: "object",
        properties: %{path: %{type: "string", description: "Directory path to list"}},
        required: ["path"]
      }
    },
    %{
      name: "execute_command",
      description: "Execute a shell command and return its output.",
      input_schema: %{
        type: "object",
        properties: %{
          command: %{type: "string", description: "Shell command to execute"},
          working_dir: %{
            type: "string",
            description: "Working directory (optional, must be an allowed directory)"
          }
        },
        required: ["command"]
      }
    },
    %{
      name: "search_files",
      description: "Search for files matching a pattern or search file contents for text.",
      input_schema: %{
        type: "object",
        properties: %{
          pattern: %{type: "string", description: "Filename glob pattern (e.g. \"*.ex\")"},
          path: %{type: "string", description: "Directory to search in (optional)"},
          content: %{type: "string", description: "Search file contents for this text (optional)"}
        },
        required: ["pattern"]
      }
    }
  ]

  # --- Client API ---

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    task_id = Keyword.get(opts, :task_id)
    model = Keyword.get(opts, :model)
    session = Sessions.get_session(session_id)
    system_prompt = Keyword.get(opts, :system_prompt) || code_system_prompt()

    messages =
      Sessions.list_messages(session_id)
      |> Enum.map(fn msg -> %{role: normalize_role(msg.role), content: msg.content} end)

    # Working directories that tools are allowed to access.
    # Defaults to the current working directory if not specified.
    working_dirs =
      Keyword.get(opts, :working_dirs) || session_working_dirs(session) || [File.cwd!()]

    state = %__MODULE__{
      session_id: session_id,
      task_id: task_id,
      messages: messages,
      system_prompt: system_prompt,
      model: model,
      working_dirs: working_dirs
    }

    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    broadcast_task_status(state.session_id, state.task_id, "running")
    run_agent_loop(state, 0)
    {:stop, :normal, state}
  end

  # --- Agent Loop ---

  defp run_agent_loop(state, iteration) when iteration >= @max_iterations do
    broadcast_chunk(
      state.session_id,
      "\n\n[Agent reached maximum iterations (#{@max_iterations})]"
    )

    broadcast_task_status(state.session_id, state.task_id, "completed")
  end

  defp run_agent_loop(state, iteration) do
    opts = [
      system: state.system_prompt,
      tools: @tools,
      on_chunk: fn text -> broadcast_chunk(state.session_id, text) end
    ]

    opts = if state.model, do: Keyword.put(opts, :model, state.model), else: opts

    case Anthropic.stream_message(state.messages, opts) do
      {:ok, %{content: content, usage: usage, stop_reason: stop_reason}} ->
        handle_agent_response(state, content, usage, stop_reason, iteration)

      {:error, reason} ->
        broadcast_chunk(state.session_id, "\n\n[Error: #{inspect(reason)}]")
        broadcast_task_status(state.session_id, state.task_id, "failed")
    end
  end

  defp handle_agent_response(state, content, usage, stop_reason, iteration) do
    stored_content = extract_text_content(content)

    {:ok, message} =
      Sessions.create_message(%{
        session_id: state.session_id,
        role: "assistant",
        content: stored_content,
        token_count: Map.get(usage, :output_tokens, 0),
        model: state.model || "claude-sonnet-4-20250514"
      })

    Phoenix.PubSub.broadcast(
      James.PubSub,
      "session:#{state.session_id}",
      {:assistant_message, message}
    )

    record_tokens(state, usage)

    if stop_reason == "tool_use" do
      continue_with_tool_results(state, content, iteration)
    else
      broadcast_task_status(state.session_id, state.task_id, "completed")
    end
  end

  defp continue_with_tool_results(state, content, iteration) do
    tool_results = execute_tool_calls(content, state)

    tool_text =
      Enum.map_join(tool_results, "\n---\n", fn r ->
        "[Tool #{r[:tool_use_id]}]\n#{r[:content]}"
      end)

    Sessions.create_message(%{
      session_id: state.session_id,
      role: "system",
      content: tool_text
    })

    updated_messages =
      state.messages ++
        [
          %{role: "assistant", content: content},
          %{role: "user", content: tool_results}
        ]

    run_agent_loop(%{state | messages: updated_messages}, iteration + 1)
  end

  # --- Tool Dispatch ---

  # If the model returned plain text (no tools involved), nothing to execute.
  defp execute_tool_calls(content, _state) when is_binary(content), do: []

  defp execute_tool_calls(content, state) when is_list(content) do
    content
    |> Enum.filter(fn block -> is_map(block) and Map.get(block, "type") == "tool_use" end)
    |> Enum.map(fn tool_call ->
      result = execute_tool(tool_call["name"], tool_call["input"] || %{}, state)

      %{
        type: "tool_result",
        tool_use_id: tool_call["id"],
        content: result
      }
    end)
  end

  defp execute_tool("read_file", %{"path" => path}, state) do
    with :ok <- validate_path(path, state.working_dirs),
         {:ok, content} <- File.read(path) do
      content
    else
      {:error, :path_not_allowed} -> "Error: path is outside allowed working directories"
      {:error, reason} -> "Error reading file: #{:file.format_error(reason)}"
    end
  end

  defp execute_tool("write_file", %{"path" => path, "content" => content}, state) do
    with :ok <- validate_path(path, state.working_dirs),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, content) do
      "File written successfully: #{path}"
    else
      {:error, :path_not_allowed} -> "Error: path is outside allowed working directories"
      {:error, reason} -> "Error writing file: #{:file.format_error(reason)}"
    end
  end

  defp execute_tool("list_directory", %{"path" => path}, state) do
    with :ok <- validate_path(path, state.working_dirs),
         {:ok, entries} <- File.ls(path) do
      entries |> Enum.sort() |> Enum.join("\n")
    else
      {:error, :path_not_allowed} -> "Error: path is outside allowed working directories"
      {:error, reason} -> "Error listing directory: #{:file.format_error(reason)}"
    end
  end

  defp execute_tool("execute_command", %{"command" => command} = input, state) do
    dir = Map.get(input, "working_dir") || hd(state.working_dirs)

    case validate_path(dir, state.working_dirs) do
      :ok -> run_command(command, dir)
      {:error, :path_not_allowed} -> "Error: working directory is outside allowed directories"
    end
  end

  defp run_command(command, dir) do
    {output, exit_code} =
      System.cmd("sh", ["-c", command],
        cd: dir,
        stderr_to_stdout: true
      )

    "Exit code: #{exit_code}\n#{output}"
  rescue
    e -> "Error executing command: #{Exception.message(e)}"
  end

  defp execute_tool("search_files", %{"pattern" => pattern} = input, state) do
    dir = Map.get(input, "path") || hd(state.working_dirs)

    case validate_path(dir, state.working_dirs) do
      :ok -> run_search(pattern, dir, Map.get(input, "content"))
      {:error, :path_not_allowed} -> "Error: path is outside allowed working directories"
    end
  end

  defp run_search(pattern, dir, content_search) do
    if content_search do
      {output, _} =
        System.cmd(
          "grep",
          ["-rl", "--include=#{pattern}", content_search, dir],
          stderr_to_stdout: true
        )

      if output == "", do: "(no matches)", else: String.trim(output)
    else
      {output, _} =
        System.cmd("find", [dir, "-name", pattern, "-type", "f"], stderr_to_stdout: true)

      if output == "", do: "(no files found)", else: String.trim(output)
    end
  rescue
    e -> "Error searching files: #{Exception.message(e)}"
  end

  defp execute_tool(name, _input, _state) do
    "Error: unknown tool '#{name}'"
  end

  # --- Path Validation ---

  defp validate_path(path, working_dirs) do
    expanded = Path.expand(path)

    if Enum.any?(working_dirs, fn dir -> String.starts_with?(expanded, Path.expand(dir)) end) do
      :ok
    else
      {:error, :path_not_allowed}
    end
  end

  # --- Helpers ---

  defp extract_text_content(content) when is_binary(content), do: content

  defp extract_text_content(content) when is_list(content) do
    content
    |> Enum.filter(fn b -> is_map(b) and Map.get(b, "type") == "text" end)
    |> Enum.map_join("\n", fn b -> Map.get(b, "text", "") end)
  end

  defp broadcast_chunk(session_id, text) do
    Phoenix.PubSub.broadcast(James.PubSub, "session:#{session_id}", {:assistant_chunk, text})
  end

  defp broadcast_task_status(_session_id, nil, _status), do: :ok

  defp broadcast_task_status(session_id, task_id, status) do
    case Tasks.get_task(task_id) do
      nil ->
        :ok

      task ->
        {:ok, updated} = Tasks.update_task_status(task, status)

        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:task_updated, updated}
        )
    end
  end

  defp record_tokens(state, usage) do
    input = Map.get(usage, :input_tokens, 0)
    output = Map.get(usage, :output_tokens, 0)

    if input > 0 or output > 0 do
      Tokens.record_usage(%{
        session_id: state.session_id,
        task_id: state.task_id,
        model: state.model || "claude-sonnet-4-20250514",
        input_tokens: input,
        output_tokens: output,
        cost_usd: estimate_cost(input, output)
      })
    end
  end

  defp estimate_cost(input, output) do
    # Sonnet pricing: $3/M input, $15/M output
    Decimal.add(
      Decimal.div(Decimal.new(input * 3), Decimal.new(1_000_000)),
      Decimal.div(Decimal.new(output * 15), Decimal.new(1_000_000))
    )
  end

  defp normalize_role("user"), do: "user"
  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role(_), do: "user"

  defp session_working_dirs(nil), do: nil
  defp session_working_dirs(%{metadata: %{"working_dirs" => dirs}}) when is_list(dirs), do: dirs
  defp session_working_dirs(_), do: nil

  defp code_system_prompt do
    """
    You are James the Butler, a code-focused AI agent with filesystem and shell access.

    Available tools:
    - read_file: Read the contents of a file
    - write_file: Create or overwrite a file
    - list_directory: List the contents of a directory
    - execute_command: Run a shell command (sh -c) and capture stdout/stderr
    - search_files: Find files by name pattern, or search file contents with grep

    Guidelines:
    - Always read a file before modifying it so you understand the existing code
    - Make targeted, minimal changes — avoid rewriting code that doesn't need to change
    - Explain what you are doing and why before each tool call
    - Use execute_command for git operations, builds, and running tests
    - Validate your changes by running relevant tests after editing
    - Never access paths outside the configured working directories
    """
  end
end
