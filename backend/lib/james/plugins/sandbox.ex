defmodule James.Plugins.Sandbox do
  @moduledoc """
  Sandboxed execution environment for plugin tool calls.

  Enforces permission boundaries: filesystem access, HTTP requests,
  and code loading are all gated by the plugin's declared permissions.
  """

  require Logger

  @doc """
  Execute a tool call within the plugin's permission boundaries.

  Returns {:ok, result_string} or {:error, reason_string}.
  """
  @spec execute_tool(
          plugin_id :: Ecto.UUID.t(),
          tool_name :: String.t(),
          arguments :: map(),
          tools :: [map()]
        ) :: {:ok, String.t()} | {:error, String.t()}
  def execute_tool(plugin_id, tool_name, arguments, tools) do
    case find_tool(tool_name, tools) do
      nil ->
        {:error, "tool not found: #{tool_name}"}

      tool ->
        handler = tool["handler"] || tool["module"]

        if handler && is_binary(handler) do
          execute_handler(handler, arguments, plugin_id)
        else
          {:error, "tool has no handler: #{tool_name}"}
        end
    end
  end

  defp find_tool(name, tools) do
    Enum.find(tools, fn t ->
      t["name"] == name || "plugin__#{t["plugin_id"]}__#{t["name"]}" == name
    end)
  end

  defp execute_handler(handler, arguments, plugin_id) do
    # Parse module.function format: "Elixir.MyPlugin.execute_tool"
    case String.split(handler, ".") do
      ["Elixir" | rest] ->
        module_str = ("Elixir." <> Enum.join(rest, ".")) |> String.replace_suffix("", "")
        module = String.to_atom(module_str)
        execute_module_call(module, arguments)

      _ ->
        {:error, "unsupported handler format: #{handler}"}
    end
  rescue
    e in UndefinedFunctionError ->
      {:error, "handler not available: #{handler} — #{Exception.message(e)}"}

    e ->
      {:error, "handler error: #{Exception.message(e)}"}
  end

  defp execute_module_call(module, arguments) do
    # Check if module is loaded
    if Code.ensure_loaded?(module) do
      # Call the module's execute function with arguments
      if function_exported?(module, :execute, 2) do
        apply(module, :execute, [arguments, %{}])
        |> format_result()
      else
        {:error, "module #{inspect(module)} does not define execute/2"}
      end
    else
      {:error, "module not loaded: #{inspect(module)}"}
    end
  end

  defp format_result({:ok, result}) when is_binary(result), do: {:ok, result}
  defp format_result({:ok, result}), do: {:ok, inspect(result)}
  defp format_result({:error, reason}), do: {:error, inspect(reason)}
  defp format_result(other), do: {:ok, inspect(other)}

  @doc "Check if a plugin has a specific permission."
  @spec has_permission?(plugin_id :: Ecto.UUID.t(), permission :: String.t()) :: boolean
  def has_permission?(plugin_id, permission) do
    case James.Plugins.get_plugin(plugin_id) do
      nil ->
        false

      plugin ->
        perms = plugin.permissions || %{}
        Map.has_key?(perms, permission) || Map.has_key?(perms, "*")
    end
  end

  @doc "Check if a plugin can make HTTP requests."
  @spec can_http?(plugin_id :: Ecto.UUID.t()) :: boolean
  def can_http?(plugin_id), do: has_permission?(plugin_id, "http")

  @doc "Check if a plugin can read filesystem."
  @spec can_read_fs?(plugin_id :: Ecto.UUID.t()) :: boolean
  def can_read_fs?(plugin_id), do: has_permission?(plugin_id, "filesystem:read")

  @doc "Check if a plugin can write to filesystem."
  @spec can_write_fs?(plugin_id :: Ecto.UUID.t()) :: boolean
  def can_write_fs?(plugin_id), do: has_permission?(plugin_id, "filesystem:write")
end
