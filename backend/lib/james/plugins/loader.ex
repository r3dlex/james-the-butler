defmodule James.Plugins.Loader do
  @moduledoc """
  Loads and validates a plugin from its manifest.

  Parses the plugin manifest, validates permissions, and returns
  the plugin's declared tools, skills, and hook handlers.
  """

  require Logger

  @doc "Load a plugin and return its validated state."
  @spec load_plugin(James.Plugins.Plugin.t()) ::
          {:ok, %{tools: list(), hooks: list()}} | {:error, term}
  def load_plugin(%James.Plugins.Plugin{} = plugin) do
    manifest = plugin.manifest || %{}

    with {:ok, tools} <- validate_tools(manifest["tools"] || []),
         {:ok, skills} <- validate_skills(manifest["skills"] || []),
         {:ok, hooks} <- validate_hooks(manifest["hooks"] || []),
         :ok <- validate_permissions(plugin, manifest) do
      {:ok, %{tools: tools, skills: skills, hooks: hooks}}
    else
      {:error, reason} = error ->
        Logger.warning("Plugin manifest validation failed",
          plugin_id: plugin.id,
          name: plugin.name,
          reason: inspect(reason)
        )

        error
    end
  end

  defp validate_tools(tools) when is_list(tools) do
    validated =
      Enum.filter(tools, fn tool ->
        is_map(tool) and is_binary(tool["name"]) and tool["name"] != ""
      end)
      |> Enum.map(fn tool ->
        %{
          "name" => tool["name"],
          "description" => tool["description"] || "",
          "input_schema" => normalize_schema(tool["input_schema"])
        }
      end)

    {:ok, validated}
  end

  defp validate_tools(other), do: {:ok, []}

  defp validate_skills(skills) when is_list(skills), do: {:ok, skills}
  defp validate_skills(_), do: {:ok, []}

  defp validate_hooks(hooks) when is_list(hooks), do: {:ok, hooks}
  defp validate_hooks(_), do: {:ok, []}

  defp validate_permissions(%{permissions: perms}, _manifest) when is_map(perms) do
    :ok
  end

  defp validate_permissions(_plugin, _manifest) do
    {:error, :invalid_permissions}
  end

  defp normalize_schema(nil), do: %{}
  defp normalize_schema(schema) when is_map(schema), do: schema
  defp normalize_schema(_), do: %{}
end
