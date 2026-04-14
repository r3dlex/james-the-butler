defmodule James.Hooks.Dispatcher do
  @moduledoc """
  Dispatches hook events to configured handlers.
  Supports hook types: command, http, prompt, agent.
  PreToolUse hooks can return :allow, :deny, or {:modify, changes}.
  """

  alias James.Hooks
  alias James.Sessions
  alias James.OpenClaw.Orchestrator
  require Logger

  @hook_timeout 30_000

  @doc """
  Fire a system-level event (no user context). Used for platform lifecycle
  events such as `session_setup`, `subagent_start`, `permission_denied`, etc.
  Always returns :ok.
  """
  @spec fire(atom(), map()) :: :ok
  def fire(event, payload) when is_atom(event) do
    Logger.info("System hook event: #{event}", payload: inspect(payload))
    :ok
  end

  @doc """
  Fire an event for a user. Returns :ok for fire-and-forget events.
  For pre_tool_use events, returns {:allow | :deny | {:modify, map}}.
  """
  @spec fire(String.t(), String.t(), map()) :: :ok | :deny | {:modify, map()}
  def fire(user_id, event, payload \\ %{}) do
    hooks = Hooks.list_hooks_for_event(user_id, event)

    if hooks == [] do
      :ok
    else
      hooks
      |> Enum.filter(&matches?(&1, payload))
      |> Enum.reduce(:ok, fn hook, acc ->
        merge_hook_result(execute_hook(hook, payload), acc)
      end)
    end
  end

  # Pre-tool and pre-prompt hooks are synchronous — must return within timeout
  @doc false
  def fire_sync(user_id, event, payload \\ %{}) do
    hooks = Hooks.list_hooks_for_event(user_id, event)

    if hooks == [] do
      :ok
    else
      hooks
      |> Enum.filter(&matches?(&1, payload))
      |> Enum.reduce(:ok, fn hook, acc ->
        merge_hook_result(execute_hook_sync(hook, payload), acc)
      end)
    end
  end

  defp merge_hook_result(:deny, _acc), do: :deny
  defp merge_hook_result({:modify, changes}, :ok), do: {:modify, changes}
  defp merge_hook_result(_result, acc), do: acc

  defp matches?(%{matcher: nil}, _payload), do: true
  defp matches?(%{matcher: ""}, _payload), do: true

  defp matches?(%{matcher: matcher}, payload) do
    tool_name = Map.get(payload, :tool_name, "")
    patterns = String.split(matcher, "|")
    Enum.any?(patterns, fn pattern -> String.contains?(tool_name, String.trim(pattern)) end)
  end

  # --- Async execution (fire-and-forget) ---

  defp execute_hook(%{type: "command"} = hook, payload) do
    command = get_in(hook.config, ["command"]) || ""

    if command != "" do
      timeout = get_in(hook.config, ["timeout_ms"]) || @hook_timeout

      Task.Supervisor.async_nolink(James.TaskSupervisor, fn ->
        do_command_hook(command, timeout)
      end)

      Logger.info("Hook #{hook.id}: command hook fired asynchronously",
        hook_id: hook.id,
        command: command
      )
    end

    :ok
  end

  defp execute_hook(%{type: "http"} = hook, payload) do
    url = get_in(hook.config, ["url"]) || ""

    if url != "" do
      Task.Supervisor.async_nolink(James.TaskSupervisor, fn ->
        do_http_hook(hook.config, payload)
      end)

      Logger.info("Hook #{hook.id}: http hook fired asynchronously", hook_id: hook.id, url: url)
    end

    :ok
  end

  defp execute_hook(%{type: "prompt"} = hook, payload) do
    # Prompt hooks are synchronous — delegate to execute_hook_sync
    execute_hook_sync(hook, payload)
  end

  defp execute_hook(%{type: "agent"} = hook, payload) do
    agent_type = get_in(hook.config, ["agent_type"]) || "chat"
    task = get_in(hook.config, ["task"]) || ""

    if task != "" do
      Task.Supervisor.async_nolink(James.TaskSupervisor, fn ->
        do_agent_hook(hook.id, agent_type, task, payload)
      end)

      Logger.info("Hook #{hook.id}: agent hook fired asynchronously",
        hook_id: hook.id,
        agent_type: agent_type
      )
    end

    :ok
  end

  defp execute_hook(_hook, _payload), do: :ok

  # --- Sync execution (for pre_tool_use, pre_prompt_submit) ---

  defp execute_hook_sync(%{type: "command"} = hook, payload) do
    command = get_in(hook.config, ["command"]) || ""
    if command == "", do: :ok, else: do_command_hook(command, @hook_timeout)
  end

  defp execute_hook_sync(%{type: "http"} = hook, payload) do
    url = get_in(hook.config, ["url"]) || ""
    if url == "", do: :ok, else: do_http_hook(hook.config, payload)
  end

  defp execute_hook_sync(%{type: "prompt"} = hook, _payload) do
    prompt = get_in(hook.config, ["prompt"]) || ""
    if prompt != "", do: {:modify, %{inject_prompt: prompt}}, else: :ok
  end

  defp execute_hook_sync(%{type: "agent"} = hook, payload) do
    # Agent hooks for pre_* events run synchronously (returns task_id)
    agent_type = get_in(hook.config, ["agent_type"]) || "chat"
    task = get_in(hook.config, ["task"]) || ""
    if task == "", do: :ok, else: do_agent_hook(hook.id, agent_type, task, payload)
  end

  defp execute_hook_sync(_hook, _payload), do: :ok

  # --- Hook implementations ---

  defp do_command_hook(command, timeout) do
    try do
      {stdout, exit_code} = System.cmd("sh", ["-c", command], timeout: timeout)
      Logger.info("Hook command completed", command: command, exit_code: exit_code)
      {:ok, stdout, exit_code}
    catch
      :exit, reason ->
        Logger.error("Hook command failed", command: command, reason: reason)
        {:error, :timeout}
    end
  end

  defp do_http_hook(config, payload) do
    url = config["url"]
    method = String.upcase(config["method"] || "POST")
    headers = config["headers"] || %{}
    body_field = config["body_field"] || "payload"
    req_body = Map.put(%{}, body_field, payload)

    try do
      case Req.request(method, url, json: req_body, headers: headers, timeout: @hook_timeout) do
        {:ok, %{status: status, body: body}} ->
          Logger.info("Hook HTTP completed", url: url, status: status)
          {:ok, status, body}

        {:error, reason} ->
          Logger.warning("Hook HTTP failed", url: url, reason: inspect(reason))
          {:error, reason}
      end
    catch
      :exit, reason ->
        Logger.error("Hook HTTP timed out", url: url, reason: reason)
        {:error, :timeout}
    end
  end

  defp do_agent_hook(hook_id, agent_type, task, payload) do
    user_id = payload[:user_id]

    attrs = %{
      user_id: user_id,
      name: "hook-#{agent_type}-#{hook_id}",
      agent_type: agent_type
    }

    case Orchestrator.start_session(attrs) do
      {:ok, session} ->
        # Queue the task as a user message
        Sessions.create_message(%{
          session_id: session.id,
          role: "user",
          content: task
        })

        Logger.info("Hook agent started",
          hook_id: hook_id,
          session_id: session.id,
          agent_type: agent_type
        )

        {:ok, session.id}

      {:error, reason} ->
        Logger.error("Hook agent failed to start", hook_id: hook_id, reason: inspect(reason))
        {:error, reason}
    end
  end
end
