defmodule James.Planner.RiskClassifier do
  @moduledoc """
  Keyword-based heuristic classifier for task risk levels.

  Scans a task description for action verbs and categorises the operation as:
  - `"read_only"` — safe, non-mutating operations (read, list, show, get, search)
  - `"additive"` — creates or produces new content (create, add, write, generate)
  - `"destructive"` — mutates, removes, or produces irreversible side-effects
    (delete, remove, drop, update, modify, send, execute)

  Defaults to `"additive"` when no recognisable verb is found.
  """

  @read_only_verbs ~w(read list show get search fetch view display)
  @additive_verbs ~w(create add write generate make build produce compose draft)
  @destructive_verbs ~w(delete remove drop update modify send execute destroy kill terminate purge wipe clear reset overwrite deploy push publish)

  @doc """
  Classify a task description string and return its risk level.

  ## Examples

      iex> James.Planner.RiskClassifier.classify("read the contents of config.json")
      "read_only"

      iex> James.Planner.RiskClassifier.classify("delete all temporary files")
      "destructive"

      iex> James.Planner.RiskClassifier.classify("create a new document")
      "additive"

  """
  @spec classify(String.t()) :: String.t()
  def classify(description) when is_binary(description) do
    words =
      description
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)

    cond do
      Enum.any?(words, &(&1 in @destructive_verbs)) -> "destructive"
      Enum.any?(words, &(&1 in @additive_verbs)) -> "additive"
      Enum.any?(words, &(&1 in @read_only_verbs)) -> "read_only"
      true -> "additive"
    end
  end
end
