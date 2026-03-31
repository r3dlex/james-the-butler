defmodule James.Tokens do
  @moduledoc """
  Token usage tracking and cost aggregation.
  """

  import Ecto.Query
  alias James.Repo
  alias James.Tokens.TokenLedger

  def list_usage(opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    model = Keyword.get(opts, :model)
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)
    limit = Keyword.get(opts, :limit, 100)

    query = from t in TokenLedger, order_by: [desc: t.inserted_at], limit: ^limit

    query = if session_id, do: from(t in query, where: t.session_id == ^session_id), else: query
    query = if model, do: from(t in query, where: t.model == ^model), else: query
    query = if from_date, do: from(t in query, where: t.inserted_at >= ^from_date), else: query
    query = if to_date, do: from(t in query, where: t.inserted_at <= ^to_date), else: query

    Repo.all(query)
  end

  def usage_summary(opts \\ []) do
    session_id = Keyword.get(opts, :session_id)

    base = from t in TokenLedger, select: %{
      model: t.model,
      total_input: sum(t.input_tokens),
      total_output: sum(t.output_tokens),
      total_cost: sum(t.cost_usd)
    }, group_by: t.model

    base = if session_id, do: from(t in base, where: t.session_id == ^session_id), else: base

    Repo.all(base)
  end

  def record_usage(attrs) do
    %TokenLedger{}
    |> TokenLedger.changeset(attrs)
    |> Repo.insert()
  end
end
