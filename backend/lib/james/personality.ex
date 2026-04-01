defmodule James.Personality do
  @moduledoc """
  Manages personality presets and generates system prompts.
  Three-level inheritance: account > project > session (most specific wins).
  """

  alias James.{Accounts, Projects}

  @presets %{
    "butler" => %{
      name: "Butler",
      prompt:
        "You are James the Butler. You are formal, measured, and precise. You address the user respectfully and provide thorough, well-structured responses. You avoid unnecessary familiarity."
    },
    "collaborator" => %{
      name: "Collaborator",
      prompt:
        "You are James, a conversational and direct collaborator. Keep responses concise and practical. Skip formalities — focus on getting things done together."
    },
    "analyst" => %{
      name: "Analyst",
      prompt:
        "You are James, a detail-oriented analyst. You cite your reasoning explicitly, present data clearly, and flag assumptions. When uncertain, say so and explain why."
    },
    "coach" => %{
      name: "Coach",
      prompt:
        "You are James, an encouraging coach. You explain your reasoning step by step, ask clarifying questions when needed, and help the user build understanding rather than just providing answers."
    },
    "editor" => %{
      name: "Editor",
      prompt:
        "You are James, a focused editor. You are document-aware and give short, precise responses. Focus on the content at hand. Minimize commentary — prioritize actionable feedback."
    },
    "silent" => %{
      name: "Silent",
      prompt:
        "You provide results only with no commentary, explanations, or pleasantries. Output the answer and nothing else."
    }
  }

  @doc """
  Returns the list of built-in preset identifiers.
  """
  def preset_ids, do: Map.keys(@presets)

  @doc """
  Returns preset metadata for a given identifier.
  """
  def get_preset(id), do: Map.get(@presets, id)

  @doc """
  Returns all presets as a list of maps with :id, :name, :prompt.
  """
  def list_presets do
    Enum.map(@presets, fn {id, p} -> %{id: id, name: p.name, prompt: p.prompt} end)
  end

  @doc """
  Returns all built-in presets as a list of maps with :id, :name, :prompt.
  Alias for `list_presets/0`.
  """
  def presets, do: list_presets()

  @doc """
  Resolves the effective system prompt for a session.
  Checks session personality → project personality → user personality → default.
  """
  def resolve_system_prompt(session) do
    personality_id =
      session.personality_id ||
        resolve_project_personality(session.project_id) ||
        resolve_user_personality(session.user_id)

    if personality_id do
      prompt_from_profile(Accounts.get_personality_profile(personality_id))
    else
      default_prompt()
    end
  end

  defp prompt_from_profile(%{custom_prompt: prompt}) when is_binary(prompt) and prompt != "" do
    prompt
  end

  defp prompt_from_profile(%{preset: preset}) when is_binary(preset) do
    prompt_from_preset(get_preset(preset))
  end

  defp prompt_from_profile(_), do: default_prompt()

  defp prompt_from_preset(%{prompt: p}), do: p
  defp prompt_from_preset(nil), do: default_prompt()

  defp resolve_project_personality(nil), do: nil

  defp resolve_project_personality(project_id) do
    case Projects.get_project(project_id) do
      %{personality_id: pid} when not is_nil(pid) -> pid
      _ -> nil
    end
  end

  defp resolve_user_personality(nil), do: nil

  defp resolve_user_personality(user_id) do
    case Accounts.get_user(user_id) do
      %{personality_id: pid} when not is_nil(pid) -> pid
      _ -> nil
    end
  end

  defp default_prompt do
    @presets["butler"].prompt
  end
end
