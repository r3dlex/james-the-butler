defmodule James.ExecutionMode do
  @moduledoc """
  Resolves the effective execution mode for a session using the three-level
  inheritance hierarchy: session → project → user (most specific wins).
  """

  alias James.{Accounts, Projects}

  @doc """
  Returns the effective execution mode for the given session.
  Falls back through: session → project → user → "direct".
  """
  def resolve(%{execution_mode: mode}) when is_binary(mode) and mode != "" do
    mode
  end

  def resolve(%{project_id: project_id, user_id: user_id}) when not is_nil(project_id) do
    case Projects.get_project(project_id) do
      %{execution_mode: mode} when is_binary(mode) and mode != "" ->
        mode

      _ ->
        resolve_from_user(user_id)
    end
  end

  def resolve(%{user_id: user_id}) do
    resolve_from_user(user_id)
  end

  def resolve(_), do: "direct"

  defp resolve_from_user(user_id) when is_binary(user_id) do
    case Accounts.get_user(user_id) do
      %{execution_mode: mode} when is_binary(mode) and mode != "" -> mode
      _ -> "direct"
    end
  end

  defp resolve_from_user(_), do: "direct"
end
