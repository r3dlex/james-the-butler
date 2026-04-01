defmodule James.Cron.Scheduler do
  @moduledoc """
  GenServer that periodically checks for due cron tasks and dispatches them.

  Every tick the scheduler:
  1. Queries `James.Cron.list_due_tasks/0` for enabled tasks whose `next_fire_at`
     is at or before now.
  2. For each due task, injects a user message into the session via
     `James.Sessions.create_message/1`.
  3. Calls `James.Cron.update_after_fire/1` to advance (or disable) the task.
  4. Reschedules itself for the next tick.

  The tick interval defaults to `60_000` ms and can be overridden via the
  `:tick_interval` option passed to `start_link/1` (useful for tests).
  """

  use GenServer

  alias James.{Cron, Sessions}

  @default_tick_interval 60_000

  # --- Client API ---

  @doc "Starts the Scheduler. Accepts `:tick_interval` (ms) in opts."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    tick_interval = Keyword.get(opts, :tick_interval, @default_tick_interval)
    Process.send_after(self(), :tick, tick_interval)
    {:ok, %{tick_interval: tick_interval}}
  end

  @impl true
  def handle_info(:tick, state) do
    Cron.list_due_tasks()
    |> Enum.each(&dispatch_task/1)

    Process.send_after(self(), :tick, state.tick_interval)
    {:noreply, state}
  end

  # --- Private ---

  defp dispatch_task(task) do
    Sessions.create_message(%{
      session_id: task.session_id,
      role: "user",
      content: task.prompt,
      metadata: %{source: "cron", cron_task_id: task.id}
    })

    Cron.update_after_fire(task)
  end
end
