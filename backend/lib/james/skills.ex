defmodule James.Skills do
  @moduledoc "Manages skill definitions stored in the database."

  import Ecto.Query
  alias James.Repo
  alias James.Skills.Skill

  use Agent
  require Logger

  def list_skills do
    from(s in Skill, order_by: [asc: s.name])
    |> Repo.all()
  end

  def get_skill(id), do: Repo.get(Skill, id)

  def get_skill_by_name(name) do
    Repo.get_by(Skill, name: name)
  end

  def start_link(_opts) do
    Agent.start_link(fn -> %{known_paths: MapSet.new()} end, name: __MODULE__)
  end

  defp get_known_paths, do: Agent.get(__MODULE__, & &1.known_paths)
  defp set_known_paths(paths), do: Agent.update(__MODULE__, &%{&1 | known_paths: paths})

  def create_skill(attrs) do
    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
    |> tap(fn {:ok, skill} -> maybe_export_skill(skill) end)
  end

  def update_skill(%Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
    |> tap(fn {:ok, updated} -> maybe_export_skill(updated) end)
  end

  def delete_skill(%Skill{} = skill) do
    name = skill.name

    Repo.delete(skill)
    |> tap(fn _ -> maybe_remove_skill(name) end)
  end

  defp maybe_export_skill(skill) do
    if _bridge = Process.whereis(James.Skills.Bridge) do
      James.Skills.Bridge.export_skill(skill)
    end
  end

  defp maybe_remove_skill(name) do
    if _bridge = Process.whereis(James.Skills.Bridge) do
      James.Skills.Bridge.remove_skill(name)
    end
  end

  @doc "Sync a skill from filesystem content. Creates or updates based on content_hash."
  def sync_skill(name, content) do
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

    case get_skill_by_name(name) do
      nil ->
        create_skill(%{name: name, content: content, content_hash: hash})

      %{content_hash: ^hash} = skill ->
        {:ok, skill}

      skill ->
        update_skill(skill, %{content: content, content_hash: hash})
    end
  end

  @doc "Reload skills from a directory (called by Skills.Watcher on config change)."
  def reload_from_dir(dir) do
    if File.exists?(dir) do
      paths = Path.wildcard(dir <> "/**/*.md")
      old_paths = get_known_paths()

      Enum.each(paths, fn path ->
        case parse_skill_file(path) do
          {:ok, name, content} ->
            sync_skill(name, content)

          {:error, reason} ->
            Logger.warning("Skipping malformed skill file #{path}: #{reason}")
        end
      end)

      new_paths = MapSet.new(paths)
      deleted_paths = MapSet.difference(old_paths, new_paths) |> MapSet.to_list()

      Enum.each(deleted_paths, fn path ->
        Logger.warning("Skill file deleted: #{path}")
      end)

      set_known_paths(new_paths)
      Logger.info("Skills reloaded from #{dir}: #{length(paths)} files")
    else
      # Directory gone: mark all known paths as deleted
      old_paths = get_known_paths()
      Enum.each(old_paths, fn path -> Logger.warning("Skill file deleted: #{path}") end)
      set_known_paths(MapSet.new())
    end

    :ok
  end

  # Parse a .md file and return {:ok, name, content} or {:error, reason}.
  defp parse_skill_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case extract_name_and_body(path, content) do
          {:ok, name, body} -> {:ok, name, body}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, "cannot read file: #{inspect(reason)}"}
    end
  end

  # Extract name and body from file content, using frontmatter if present.
  defp extract_name_and_body(path, content) do
    case parse_frontmatter(content) do
      {:ok, attrs, body} ->
        name = Map.get(attrs, "name") || Path.basename(path, ".md")
        {:ok, name, body}

      :no_frontmatter ->
        # No frontmatter: use filename as name, entire content as body
        {:ok, Path.basename(path, ".md"), content}

      :error ->
        {:error, :malformed_frontmatter}
    end
  end

  # Parse YAML frontmatter using regex. Returns {:ok, attrs, body}, :no_frontmatter, or :error.
  defp parse_frontmatter(content) do
    case extract_frontmatter_block(content) do
      {:ok, frontmatter_raw, body} ->
        {:ok, attrs} = parse_yaml_lines(frontmatter_raw)
        {:ok, attrs, body}

      :no_frontmatter ->
        :no_frontmatter

      :error ->
        :error
    end
  end

  # Extract the frontmatter block: must start with --- on its own line.
  # Returns {:ok, frontmatter_lines, body}, :no_frontmatter, or :error.
  defp extract_frontmatter_block(<<"---\n", rest::binary>>) do
    case :binary.match(rest, "\n---\n") do
      {pos, _} ->
        frontmatter_raw = binary_part(rest, 0, pos)
        body = binary_part(rest, pos + 5, byte_size(rest) - pos - 5)
        # Strip leading newline that separates frontmatter from body
        body = String.trim_leading(body)
        {:ok, frontmatter_raw, body}

      :nomatch ->
        :error
    end
  end

  defp extract_frontmatter_block(_), do: :no_frontmatter

  # Parse key: value lines from frontmatter. Returns {:ok, attrs_map}.
  defp parse_yaml_lines(frontmatter_raw) do
    lines = String.split(frontmatter_raw, "\n")
    attrs = Enum.reduce(lines, %{}, &parse_yaml_line/2)
    {:ok, attrs}
  end

  defp parse_yaml_line(line, acc) do
    case String.split(line, ":", parts: 2) do
      [key, value] ->
        key = String.trim(key)
        value = String.trim(value)
        Map.put(acc, key, value)

      [_] ->
        acc
    end
  end

  @doc """
  Sync a skill to the filesystem as a frontmatter + content .md file.
  Accepts a skill struct or a skill id.
  """
  def sync_skill_to_filesystem(%Skill{} = skill) do
    skill
    |> Map.put(:content_hash, compute_content_hash(skill.content))
    |> do_sync_skill_to_filesystem()
  end

  def sync_skill_to_filesystem(id) when is_binary(id) do
    case get_skill(id) do
      nil -> {:error, :not_found}
      skill -> sync_skill_to_filesystem(skill)
    end
  end

  defp do_sync_skill_to_filesystem(skill) do
    dir = Path.join(System.user_home(), ".claude/skills")
    File.mkdir_p!(dir)

    slug = slugify(skill.name)
    path = Path.join(dir, "#{slug}.md")
    created_at = format_datetime(skill.inserted_at)
    updated_at = format_datetime(skill.updated_at)

    frontmatter = """
    ---
    name: #{skill.name}
    description: #{Map.get(skill, :description) || ""}
    agent_type: #{Map.get(skill, :agent_type) || "chat"}
    content_hash: #{skill.content_hash}
    created_at: #{created_at}
    updated_at: #{updated_at}
    ---
    """

    content = frontmatter <> (skill.content || "")

    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Import skills from `System.user_home() <> "/.claude/skills/"`.
  Parses frontmatter from all .md files and inserts/updates skills in the DB.
  """
  def import_from_claude_code do
    dir = Path.join(System.user_home(), ".claude/skills")

    if File.exists?(dir) do
      paths = Path.wildcard(dir <> "/*.md")

      results =
        Enum.map(paths, fn path ->
          case File.read(path) do
            {:ok, content} ->
              case parse_frontmatter(content) do
                {:ok, attrs, body} ->
                  name = Map.get(attrs, "name") || Path.basename(path, ".md")
                  content_hash = Map.get(attrs, "content_hash") || compute_content_hash(body)

                  skill_attrs = %{
                    name: name,
                    content: body,
                    content_hash: content_hash
                  }

                  create_skill(skill_attrs)

                :no_frontmatter ->
                  name = Path.basename(path, ".md")
                  body = content
                  content_hash = compute_content_hash(body)

                  create_skill(%{name: name, content: body, content_hash: content_hash})

                :error ->
                  {:error, {:malformed_frontmatter, path}}
              end

            {:error, reason} ->
              {:error, {:cannot_read_file, path, reason}}
          end
        end)

      {:ok, results}
    else
      {:error, :dir_not_found}
    end
  end

  # Ensure consistent content_hash format
  defp compute_content_hash(content) do
    :crypto.hash(:sha256, content || "") |> Base.encode16(case: :lower)
  end

  # Slugify a name: lowercase, spaces to dashes, remove unsafe chars
  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/[^a-z0-9\-]/, "")
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(dt) do
    dt
    |> DateTime.to_iso8601()
    |> String.replace("Z", "+00:00")
  end
end
