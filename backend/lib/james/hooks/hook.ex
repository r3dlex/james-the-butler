defmodule James.Hooks.Hook do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @events ~w[
    session_start session_end session_suspend
    session_setup
    pre_tool_use post_tool_use post_tool_use_failure
    pre_prompt_submit user_prompt_submit
    task_start task_complete task_failed
    subagent_start subagent_stop
    teammate_idle
    permission_denied
    pre_desktop_action post_desktop_action
    pre_browser_action post_browser_action
    memory_extracted config_change
    checkpoint_created rewind_executed
  ]

  @types ~w[command http prompt agent]

  schema "hooks" do
    field :scope, :string, default: "account"
    field :event, :string
    field :type, :string
    field :config, :map, default: %{}
    field :matcher, :string
    field :enabled, :boolean, default: true

    belongs_to :user, James.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(hook, attrs) do
    hook
    |> cast(attrs, [:user_id, :scope, :event, :type, :config, :matcher, :enabled])
    |> validate_required([:user_id, :event, :type])
    |> validate_inclusion(:event, @events)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:scope, ~w[account project session plugin])
  end

  def valid_events, do: @events
  def valid_types, do: @types
end
