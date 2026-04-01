defmodule James.Skills.Watcher do
  @moduledoc """
  GenServer that polls a skills directory for changes and triggers a skill
  reload when `.md` files are added or modified.

  Rather than relying on the `file_system` hex package (which is not a
  project dependency), this watcher uses a periodic `File.ls` + `File.stat`
  approach to detect new files and mtime changes.

  ## Configuration

  Start the watcher with:

      James.Skills.Watcher.start_link(dir: "/path/to/skills")

  Optional keyword arguments:

    * `:poll_interval` — milliseconds between polls (default `5_000`).
    * `:on_change` — 0-arity callback invoked when changes are detected
      (default fires the `:config_change` hook via `James.Hooks.Dispatcher`
      and calls `James.Skills.reload_from_dir/1`).
  """

  use GenServer

  alias James.Hooks.Dispatcher
  alias James.Skills

  require Logger

  @default_poll_interval 5_000

  defstruct [:dir, :poll_interval, :on_change, mtimes: %{}, debounce_ref: nil]

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc "Starts the watcher linked to the calling process."
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Immediately checks the watched directory for changes.

  Returns `{:changed, [path]}` when at least one `.md` file has been added or
  modified, or `:unchanged` when nothing has changed.  The internal mtime
  snapshot is updated in both cases.
  """
  @spec check_for_changes(GenServer.server()) :: {:changed, [String.t()]} | :unchanged
  def check_for_changes(server) do
    GenServer.call(server, :check_for_changes)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    dir = Keyword.fetch!(opts, :dir)
    interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    on_change = Keyword.get(opts, :on_change)

    state = %__MODULE__{
      dir: dir,
      poll_interval: interval,
      on_change: on_change,
      mtimes: snapshot_mtimes(dir)
    }

    schedule_poll(interval)
    {:ok, state}
  end

  @impl true
  def handle_call(:check_for_changes, _from, state) do
    {changed_paths, new_mtimes} = detect_changes(state.dir, state.mtimes)

    new_state = %{state | mtimes: new_mtimes}

    if changed_paths == [] do
      {:reply, :unchanged, new_state}
    else
      {:reply, {:changed, changed_paths}, new_state}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    schedule_poll(state.poll_interval)

    {changed_paths, new_mtimes} = detect_changes(state.dir, state.mtimes)

    new_state =
      if changed_paths == [] do
        %{state | mtimes: new_mtimes}
      else
        debounce_reload(%{state | mtimes: new_mtimes}, changed_paths)
      end

    {:noreply, new_state}
  end

  def handle_info({:fire_reload, _paths}, state) do
    fire_on_change(state)
    {:noreply, %{state | debounce_ref: nil}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  # Snapshot current mtimes for all .md files in dir.
  defp snapshot_mtimes(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.reduce(%{}, &add_mtime(dir, &1, &2))

      {:error, _} ->
        %{}
    end
  end

  defp add_mtime(dir, file, acc) do
    path = Path.join(dir, file)

    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> Map.put(acc, path, mtime)
      _ -> acc
    end
  end

  # Returns {list_of_changed_paths, new_mtime_map}.
  defp detect_changes(dir, old_mtimes) do
    new_mtimes = snapshot_mtimes(dir)

    changed =
      Enum.flat_map(new_mtimes, fn {path, mtime} ->
        if Map.get(old_mtimes, path) != mtime, do: [path], else: []
      end)

    {changed, new_mtimes}
  end

  # Cancel any pending debounce timer and schedule a new one.
  defp debounce_reload(state, paths) do
    if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)
    ref = Process.send_after(self(), {:fire_reload, paths}, 200)
    %{state | debounce_ref: ref}
  end

  defp fire_on_change(%{on_change: nil, dir: dir}) do
    Dispatcher.fire(:config_change, %{source: :skills_watcher})
    maybe_reload_skills(dir)
  end

  defp fire_on_change(%{on_change: cb}) when is_function(cb, 0), do: cb.()
  defp fire_on_change(_state), do: :ok

  defp maybe_reload_skills(dir) do
    case Code.ensure_loaded(Skills) do
      {:module, Skills} ->
        if function_exported?(Skills, :reload_from_dir, 1) do
          Skills.reload_from_dir(dir)
        end

      _ ->
        :ok
    end
  end
end
