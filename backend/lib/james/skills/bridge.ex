defmodule James.Skills.Bridge do
  @moduledoc """
  GenServer that writes skills from the James DB to `.md` files in the filesystem.

  This provides a one-way sync: James DB -> filesystem. It is the counterpart
  to the Watcher (which syncs filesystem -> James DB).

  Export directory is configurable via the `:export_dir` option on start_link.
  """

  use GenServer
  require Logger

  alias James.Skills.Skill

  defstruct [:export_dir, :known_files]

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    export_dir = Keyword.get(opts, :export_dir, System.user_home() <> "/.claude/skills")
    GenServer.start_link(__MODULE__, %{export_dir: export_dir}, name: __MODULE__)
  end

  @doc "Write a skill to the filesystem as a frontmatter + content .md file."
  def export_skill(%Skill{} = skill) do
    GenServer.call(__MODULE__, {:export_skill, skill})
  end

  @doc "Delete a skill file from the filesystem."
  def remove_skill(name) do
    GenServer.call(__MODULE__, {:remove_skill, name})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(%{export_dir: export_dir}) do
    # Create export_dir if it doesn't exist
    File.mkdir_p!(export_dir)

    # Snapshot existing .md files
    paths = Path.wildcard(export_dir <> "/**/*.md")
    known_files = MapSet.new(paths)

    Logger.info("Skills.Bridge started with export_dir: #{export_dir}")

    {:ok, %__MODULE__{export_dir: export_dir, known_files: known_files}}
  end

  @impl true
  def handle_call({:export_skill, skill}, _from, state) do
    path = Path.join(state.export_dir, "#{skill.name}.md")

    case write_skill_file(path, skill) do
      :ok ->
        new_known = MapSet.put(state.known_files, path)
        Logger.debug("Exported skill #{skill.name} to #{path}")
        {:reply, :ok, %{state | known_files: new_known}}

      {:error, reason} ->
        Logger.error("Failed to export skill #{skill.name}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:remove_skill, name}, _from, state) do
    path = Path.join(state.export_dir, "#{name}.md")

    case File.rm(path) do
      :ok ->
        new_known = MapSet.delete(state.known_files, path)
        {:reply, :ok, %{state | known_files: new_known}}

      {:error, :enoent} ->
        # File doesn't exist - that's fine, treat as success
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to remove skill #{name}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp write_skill_file(path, skill) do
    content = format_skill_content(skill)

    case File.write(path, content) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_skill_content(skill) do
    created = format_datetime(skill.inserted_at)
    updated = format_datetime(skill.updated_at)

    """
    ---
    name: #{skill.name}
    created: #{created}
    updated: #{updated}
    tags: []
    description: ""
    ---
    #{skill.content}
    """
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(datetime), do: DateTime.to_iso8601(datetime)
end
