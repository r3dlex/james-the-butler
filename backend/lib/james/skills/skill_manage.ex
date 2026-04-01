defmodule James.Skills.SkillManage do
  @moduledoc """
  Tool handler for the `skill_manage` agent tool.

  Provides a structured interface for agents to list, show, create, update,
  and delete skills. Each action returns a human-readable string result
  suitable for inclusion in an LLM response.

  ## Actions

  | Action   | Required params       | Description               |
  |----------|-----------------------|---------------------------|
  | `list`   | —                     | List all skill names      |
  | `show`   | `name`                | Show skill content        |
  | `create` | `name`, `content`     | Create a new skill        |
  | `update` | `name`, `content`     | Update an existing skill  |
  | `delete` | `name`                | Delete a skill            |
  """

  alias James.Skills

  @doc """
  Handles a `skill_manage` tool invocation.

  Returns a string result for the agent to include in its response.
  """
  @spec handle(String.t(), map()) :: String.t()
  def handle("list", _params) do
    skills = Skills.list_skills()

    if skills == [] do
      "No skills found."
    else
      lines = Enum.map_join(skills, "\n", fn s -> "- #{s.name} (#{s.content_hash})" end)
      "Skills (#{length(skills)}):\n#{lines}"
    end
  end

  def handle("show", %{"name" => name}) do
    case Skills.get_skill_by_name(name) do
      nil -> "Skill '#{name}' not found."
      skill -> "# #{skill.name}\n\n#{skill.content}"
    end
  end

  def handle("create", %{"name" => name, "content" => content}) do
    attrs = %{name: name, content: content, content_hash: compute_hash(content)}

    case Skills.create_skill(attrs) do
      {:ok, skill} -> "Skill '#{skill.name}' created (hash: #{skill.content_hash})."
      {:error, changeset} -> "Failed to create skill: #{format_errors(changeset)}"
    end
  end

  def handle("update", %{"name" => name, "content" => content}) do
    case Skills.get_skill_by_name(name) do
      nil ->
        "Skill '#{name}' not found."

      skill ->
        attrs = %{content: content, content_hash: compute_hash(content)}

        case Skills.update_skill(skill, attrs) do
          {:ok, updated} -> "Skill '#{updated.name}' updated (hash: #{updated.content_hash})."
          {:error, changeset} -> "Failed to update skill: #{format_errors(changeset)}"
        end
    end
  end

  def handle("delete", %{"name" => name}) do
    case Skills.get_skill_by_name(name) do
      nil ->
        "Skill '#{name}' not found."

      skill ->
        case Skills.delete_skill(skill) do
          {:ok, _} -> "Skill '#{name}' deleted."
          {:error, _} -> "Failed to delete skill '#{name}'."
        end
    end
  end

  def handle(action, _params) do
    "unknown action '#{action}'. Valid actions: list, show, create, update, delete."
  end

  defp compute_hash(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp format_errors(changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} -> "#{field}: #{msg}" end)
  end
end
