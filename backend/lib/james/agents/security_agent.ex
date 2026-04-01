defmodule James.Agents.SecurityAgent do
  @moduledoc """
  Agent specialized for source code security scanning and PR review.
  Analyzes code for common vulnerability patterns and provides severity-rated findings.
  """

  use GenServer, restart: :temporary

  alias James.{LLMProvider, Sessions, Tokens}

  defstruct [:session_id, :task_id, :messages, :system_prompt, :model, :working_dirs]

  @tools [
    %{
      name: "read_file",
      description: "Read the contents of a source file for security analysis.",
      input_schema: %{
        type: "object",
        properties: %{path: %{type: "string", description: "File path to read"}},
        required: ["path"]
      }
    },
    %{
      name: "scan_file",
      description: "Scan a source file for security vulnerabilities.",
      input_schema: %{
        type: "object",
        properties: %{path: %{type: "string", description: "File path to scan"}},
        required: ["path"]
      }
    },
    %{
      name: "scan_directory",
      description: "List files in a directory matching a glob pattern for security review.",
      input_schema: %{
        type: "object",
        properties: %{
          path: %{type: "string", description: "Directory path to scan"},
          pattern: %{type: "string", description: "Glob pattern to match files (e.g. *.ex)"}
        },
        required: ["path"]
      }
    },
    %{
      name: "check_dependencies",
      description: "Read a dependency manifest file to check for known vulnerable packages.",
      input_schema: %{
        type: "object",
        properties: %{
          manifest_path: %{
            type: "string",
            description: "Path to the manifest file (mix.exs, package.json, etc.)"
          }
        },
        required: ["manifest_path"]
      }
    },
    %{
      name: "generate_findings",
      description:
        "Save a structured list of security findings. Each finding must include severity, description, location, and remediation.",
      input_schema: %{
        type: "object",
        properties: %{
          findings_json: %{
            type: "string",
            description:
              "JSON array of findings. Each entry: {severity, description, location, remediation}"
          }
        },
        required: ["findings_json"]
      }
    },
    %{
      name: "search_pattern",
      description: "Search for a regex pattern across files to find potential vulnerabilities.",
      input_schema: %{
        type: "object",
        properties: %{
          pattern: %{type: "string", description: "Regex pattern to search for"},
          path: %{type: "string", description: "Directory to search"},
          file_pattern: %{type: "string", description: "File glob pattern (e.g. *.ex)"}
        },
        required: ["pattern"]
      }
    },
    %{
      name: "report_finding",
      description: "Report a security finding with severity and recommendation.",
      input_schema: %{
        type: "object",
        properties: %{
          severity: %{
            type: "string",
            enum: ["critical", "high", "medium", "low", "info"],
            description: "Severity level"
          },
          title: %{type: "string", description: "Short title of the finding"},
          description: %{type: "string", description: "Detailed description"},
          file: %{type: "string", description: "Affected file path"},
          line: %{type: "integer", description: "Affected line number"},
          recommendation: %{type: "string", description: "How to fix this issue"}
        },
        required: ["severity", "title", "description"]
      }
    }
  ]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    task_id = Keyword.get(opts, :task_id)
    model = Keyword.get(opts, :model)
    working_dirs = Keyword.get(opts, :working_dirs, [File.cwd!()])

    messages =
      Sessions.list_messages(session_id)
      |> Enum.map(fn msg -> %{role: normalize_role(msg.role), content: msg.content} end)

    state = %__MODULE__{
      session_id: session_id,
      task_id: task_id,
      messages: messages,
      system_prompt: security_system_prompt(),
      model: model,
      working_dirs: working_dirs
    }

    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    broadcast_task_status(state.session_id, state.task_id, "running")
    run_loop(state, 0)
    {:stop, :normal, state}
  end

  defp run_loop(state, iteration) when iteration >= 20 do
    broadcast_chunk(state.session_id, "\n\n[Security scan reached maximum iterations]")
    broadcast_task_status(state.session_id, state.task_id, "completed")
  end

  defp run_loop(state, iteration) do
    opts = [
      system: state.system_prompt,
      tools: @tools,
      on_chunk: fn text -> broadcast_chunk(state.session_id, text) end
    ]

    opts = if state.model, do: Keyword.put(opts, :model, state.model), else: opts

    case LLMProvider.configured().stream_message(state.messages, opts) do
      {:ok, %{content: content, usage: usage, stop_reason: stop_reason}} ->
        {:ok, message} =
          Sessions.create_message(%{
            session_id: state.session_id,
            role: "assistant",
            content: extract_text_content(content),
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
          tool_results = execute_tool_calls(content, state)

          updated_messages =
            state.messages ++
              [
                %{role: "assistant", content: content},
                %{role: "user", content: tool_results}
              ]

          run_loop(%{state | messages: updated_messages}, iteration + 1)
        else
          broadcast_task_status(state.session_id, state.task_id, "completed")
        end

      {:error, reason} ->
        broadcast_chunk(state.session_id, "\n\n[Error: #{inspect(reason)}]")
        broadcast_task_status(state.session_id, state.task_id, "failed")
    end
  end

  defp execute_tool_calls(content, _state) when is_binary(content), do: []

  defp execute_tool_calls(content, state) when is_list(content) do
    content
    |> Enum.filter(fn b -> is_map(b) and Map.get(b, "type") == "tool_use" end)
    |> Enum.map(fn tc ->
      result = execute_tool(tc["name"], tc["input"] || %{}, state)
      %{type: "tool_result", tool_use_id: tc["id"], content: result}
    end)
  end

  defp execute_tool("read_file", %{"path" => path}, state) do
    if path_allowed?(path, state.working_dirs) do
      case File.read(path) do
        {:ok, content} -> content
        {:error, reason} -> "Error: #{reason}"
      end
    else
      "Error: Path not in allowed directories"
    end
  end

  defp execute_tool("scan_file", %{"path" => path}, state) do
    if path_allowed?(path, state.working_dirs) do
      case File.read(path) do
        {:ok, content} -> content
        {:error, reason} -> "Error reading file: #{reason}"
      end
    else
      "Error: Path not in allowed directories"
    end
  end

  defp execute_tool("scan_directory", %{"path" => path} = input, state) do
    if path_allowed?(path, state.working_dirs) do
      pattern = Map.get(input, "pattern", "**/*")
      glob = Path.join(path, pattern)

      files =
        glob
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      case files do
        [] -> "No files matched pattern: #{glob}"
        list -> Enum.join(list, "\n")
      end
    else
      "Error: Path not in allowed directories"
    end
  end

  defp execute_tool("check_dependencies", %{"manifest_path" => path}, state) do
    if path_allowed?(path, state.working_dirs) do
      case File.read(path) do
        {:ok, content} -> content
        {:error, reason} -> "Error reading manifest: #{reason}"
      end
    else
      "Error: Path not in allowed directories"
    end
  end

  defp execute_tool("generate_findings", %{"findings_json" => json}, state) do
    case Jason.decode(json) do
      {:ok, findings} when is_list(findings) ->
        report = format_findings_report(findings)

        Sessions.create_message(%{
          session_id: state.session_id,
          role: "system",
          content: report
        })

        "#{length(findings)} finding(s) saved."

      {:ok, _} ->
        "Error: findings_json must be a JSON array"

      {:error, reason} ->
        "Error: Invalid JSON — #{inspect(reason)}"
    end
  end

  defp execute_tool("search_pattern", %{"pattern" => pattern} = input, state) do
    dir = Map.get(input, "path") || hd(state.working_dirs)

    if path_allowed?(dir, state.working_dirs) do
      file_pattern = Map.get(input, "file_pattern", "*")
      args = ["-rn", pattern, dir, "--include=#{file_pattern}"]

      case System.cmd("grep", args, stderr_to_stdout: true) do
        {output, 0} -> String.slice(output, 0, 10_000)
        {_output, 1} -> "No matches found."
        {output, _} -> "Error: #{output}"
      end
    else
      "Error: Path not in allowed directories"
    end
  end

  defp execute_tool("report_finding", input, state) do
    severity = Map.get(input, "severity", "info")
    title = Map.get(input, "title", "Untitled")
    desc = Map.get(input, "description", "")
    file = Map.get(input, "file")
    line = Map.get(input, "line")
    rec = Map.get(input, "recommendation", "")

    finding = """
    ### [#{String.upcase(severity)}] #{title}
    #{if file, do: "**File:** #{file}#{if line, do: ":#{line}", else: ""}", else: ""}
    #{desc}
    #{if rec != "", do: "**Recommendation:** #{rec}", else: ""}
    """

    Sessions.create_message(%{
      session_id: state.session_id,
      role: "system",
      content: finding
    })

    "Finding reported: [#{severity}] #{title}"
  end

  defp execute_tool(name, _input, _state), do: "Unknown tool: #{name}"

  defp format_findings_report(findings) do
    header = "## Security Findings (#{length(findings)} total)\n\n"

    body =
      findings
      |> Enum.with_index(1)
      |> Enum.map_join("\n\n", fn {finding, idx} ->
        severity = Map.get(finding, "severity", Map.get(finding, :severity, "unknown"))
        description = Map.get(finding, "description", Map.get(finding, :description, ""))
        location = Map.get(finding, "location", Map.get(finding, :location, ""))
        remediation = Map.get(finding, "remediation", Map.get(finding, :remediation, ""))

        """
        ### #{idx}. [#{String.upcase(to_string(severity))}] #{description}
        **Location:** #{location}
        **Remediation:** #{remediation}\
        """
      end)

    header <> body
  end

  defp extract_text_content(content) when is_binary(content), do: content

  defp extract_text_content(content) when is_list(content) do
    content
    |> Enum.filter(fn b -> is_map(b) and Map.get(b, "type") == "text" end)
    |> Enum.map_join("\n", fn b -> Map.get(b, "text", "") end)
  end

  defp path_allowed?(path, working_dirs) do
    expanded = Path.expand(path)
    Enum.any?(working_dirs, fn dir -> String.starts_with?(expanded, Path.expand(dir)) end)
  end

  defp broadcast_chunk(sid, text) do
    Phoenix.PubSub.broadcast(James.PubSub, "session:#{sid}", {:assistant_chunk, text})
  end

  defp broadcast_task_status(_sid, nil, _status), do: :ok

  defp broadcast_task_status(sid, task_id, status) do
    case James.Tasks.get_task(task_id) do
      nil ->
        :ok

      task ->
        {:ok, updated} = James.Tasks.update_task_status(task, status)
        Phoenix.PubSub.broadcast(James.PubSub, "session:#{sid}", {:task_updated, updated})
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
        cost_usd:
          Decimal.add(
            Decimal.div(Decimal.new(input * 3), Decimal.new(1_000_000)),
            Decimal.div(Decimal.new(output * 15), Decimal.new(1_000_000))
          )
      })
    end
  end

  defp normalize_role("user"), do: "user"
  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role(_), do: "user"

  defp security_system_prompt do
    """
    You are James the Butler, a security-focused AI agent. You scan source code for vulnerabilities and provide severity-rated findings.

    Available tools:
    - scan_file: Scan a single source file for vulnerabilities
    - scan_directory: List files in a directory matching a glob pattern
    - check_dependencies: Read a dependency manifest to check for vulnerable packages
    - generate_findings: Save a structured list of findings (severity, description, location, remediation)
    - read_file: Read source files
    - search_pattern: Search for vulnerability patterns across files
    - report_finding: Report an individual security finding

    Focus areas:
    - Injection vulnerabilities (SQL, command, XSS)
    - Authentication and authorization issues
    - Sensitive data exposure
    - Insecure configurations
    - Dependency vulnerabilities
    - OWASP Top 10

    For each finding, provide:
    - Severity level (high/medium/low)
    - Clear description of the vulnerability
    - Specific file and line location
    - Concrete remediation recommendation

    Use generate_findings to produce the final structured report.
    """
  end
end
