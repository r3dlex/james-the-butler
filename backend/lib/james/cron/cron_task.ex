defmodule James.Cron.CronTask do
  @moduledoc """
  Ecto schema for session-scoped cron tasks that enable agent self-scheduling.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias James.Cron.Parser

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "session_cron_tasks" do
    field :cron_expression, :string
    field :prompt, :string
    field :recurring, :boolean, default: true
    field :durable, :boolean, default: false
    field :enabled, :boolean, default: true
    field :last_fired_at, :utc_datetime_usec
    field :next_fire_at, :utc_datetime_usec
    field :max_age_days, :integer, default: 30
    field :expires_at, :utc_datetime_usec

    belongs_to :session, James.Sessions.Session

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:session_id, :cron_expression, :prompt, :next_fire_at]
  @optional_fields [:recurring, :durable, :enabled, :last_fired_at, :max_age_days, :expires_at]

  def changeset(cron_task, attrs) do
    cron_task
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_cron_expression()
    |> validate_number(:max_age_days, greater_than: 0)
  end

  defp validate_cron_expression(changeset) do
    validate_change(changeset, :cron_expression, fn :cron_expression, expr ->
      case Parser.parse(expr) do
        :ok -> []
        {:error, :invalid_cron} -> [cron_expression: "is not a valid 5-field cron expression"]
      end
    end)
  end
end
