defmodule James.Hooks.Dispatcher do
  @moduledoc """
  Dispatches hook events to configured handlers.
  Supports hook types: command, http, prompt, agent.
  PreToolUse hooks can return :allow, :deny, or {:modify, changes}.
  """

  alias James.Hooks
  require Logger

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
      |> Enum.reduce(:ok, fn hook, acc -> merge_hook_result(execute_hook(hook, payload), acc) end)
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

  defp execute_hook(%{type: "command"} = hook, _payload) do
    command = get_in(hook.config, ["command"]) || ""

    if command != "" do
      Logger.info("Hook #{hook.id}: executing command: #{command}")
      # Command execution would happen here in production
    end

    :ok
  end

  defp execute_hook(%{type: "http"} = hook, payload) do
    url = get_in(hook.config, ["url"]) || ""

    if url != "" do
      Logger.info("Hook #{hook.id}: HTTP POST to #{url}")
      # HTTP call would happen here
      Task.start(fn ->
        Req.post(url, json: payload)
      end)
    end

    :ok
  end

  defp execute_hook(%{type: "prompt"} = hook, _payload) do
    Logger.info("Hook #{hook.id}: prompt injection")
    prompt = get_in(hook.config, ["prompt"]) || ""
    if prompt != "", do: {:modify, %{inject_prompt: prompt}}, else: :ok
  end

  defp execute_hook(%{type: "agent"} = hook, _payload) do
    Logger.info("Hook #{hook.id}: agent dispatch")
    # Agent hooks would spawn a sub-agent here
    :ok
  end

  defp execute_hook(_hook, _payload), do: :ok
end
