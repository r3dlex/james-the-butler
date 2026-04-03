defmodule James.CodebaseSearch do
  @moduledoc """
  Indexes and searches codebase files using vector embeddings.

  Files are chunked at ~250 char boundaries with 100 char overlap,
  embedded, and stored in the memories table with memory_type
  `codebase_navigation`. Git-tracked files only; size limits apply.
  """

  import Ecto.Query
  require Logger

  alias James.Embeddings
  alias James.Memories
  alias James.Memories.Memory
  alias James.Repo

  @type search_result :: %{
          content: String.t(),
          file: String.t(),
          line: non_neg_integer(),
          score: float()
        }

  @extensions [
    ".ex",
    ".exs",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".py",
    ".rs",
    ".go",
    ".java",
    ".rb",
    ".md",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".sh",
    ".bash"
  ]

  @default_extensions Application.compile_env(:james, :codebase_search_extensions, @extensions)
  @default_chunk_size 250
  @default_chunk_overlap 100
  @max_file_size_bytes 500 * 1024
  @medium_file_size_bytes 50 * 1024
  @medium_file_embed_bytes 50 * 1024

  @doc """
  Index files from a working directory asynchronously via TaskSupervisor.

  Uses `git ls-files` to get only tracked files, filters by extension and
  size (skips >500KB, embeds first 50KB of 50-500KB files, embeds <50KB fully),
  chunks at ~250 char boundaries with 100 char overlap, then stores each chunk
  as a memory with memory_type `codebase_navigation`.

  Runs non-blocking via `TaskSupervisor.async_nolink`.
  """
  @spec index_working_directory(
          user_id :: Ecto.UUID.t(),
          dir_path :: String.t(),
          opts :: Keyword.t()
        ) ::
          {:ok, task :: Task.t()} | {:error, String.t()}
  def index_working_directory(user_id, dir_path, opts \\ []) when is_binary(dir_path) do
    extensions = Keyword.get(opts, :extensions, @default_extensions)
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    chunk_overlap = Keyword.get(opts, :chunk_overlap, @default_chunk_overlap)

    with {:ok, files} <- list_git_files(dir_path) do
      valid_files = filter_files(files, extensions)

      task =
        James.TaskSupervisor
        |> Task.Supervisor.async_nolink(fn ->
          process_files(user_id, dir_path, valid_files, chunk_size, chunk_overlap)
        end)

      {:ok, task}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Search indexed codebase chunks. Returns results sorted by cosine similarity descending.

  Generates an embedding for the query text and finds the most similar
  codebase_navigation memories for the user.
  """
  @spec search(user_id :: Ecto.UUID.t(), query :: String.t(), limit :: pos_integer()) ::
          {:ok, [search_result]} | {:error, String.t()}
  def search(user_id, query, limit \\ 5) when is_binary(query) and limit > 0 do
    case Embeddings.generate(query) do
      {:ok, embedding} ->
        memories =
          from(m in Memory,
            where: m.user_id == ^user_id,
            where: m.memory_type == "codebase_navigation",
            order_by: fragment("embedding <=> ?", ^embedding),
            limit: ^limit
          )
          |> Repo.all()

        results =
          Enum.map(memories, fn memory ->
            %{
              content: memory.content,
              file: metadata_for(memory).file,
              line: metadata_for(memory).line,
              score: cosine_score(embedding, memory.embedding)
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, "embedding generation failed: #{reason}"}
    end
  end

  @doc """
  Returns the list of indexed file extensions.
  """
  @spec extensions() :: [String.t()]
  def extensions, do: @default_extensions

  @doc """
  Checks if a file size is within the indexable limit (≤500KB).
  """
  @spec within_size_limit?(non_neg_integer()) :: boolean()
  def within_size_limit?(size_bytes) do
    size_bytes > 0 and size_bytes <= @max_file_size_bytes
  end

  @doc """
  Checks if a file extension is in the configured extensions list.
  """
  @spec extension_matches?(String.t(), [String.t()]) :: boolean()
  def extension_matches?(ext, extensions) do
    ext in extensions
  end

  @doc """
  Chunks text content into overlapping segments.
  Returns `[{chunk_text, starting_line_number}, ...]`.
  """
  @spec chunk_content(String.t(), pos_integer(), non_neg_integer()) :: [
          {String.t(), non_neg_integer()}
        ]
  def chunk_content(content, chunk_size, chunk_overlap) when is_binary(content) do
    lines = String.split(content, "\n")
    do_chunk_lines(lines, [], chunk_size, chunk_overlap, 0, [])
  end

  @doc """
  Clear all codebase_navigation memories for a user.
  """
  @spec clear_index(user_id :: Ecto.UUID.t()) :: :ok
  def clear_index(user_id) do
    from(m in Memory,
      where: m.user_id == ^user_id,
      where: m.memory_type == "codebase_navigation"
    )
    |> Repo.delete_all()

    :ok
  end

  # ─── Private ───────────────────────────────────────────────────────────────

  defp list_git_files(dir_path) do
    case System.cmd("git", ["ls-files"], cd: dir_path) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&Path.join(dir_path, &1))

        {:ok, files}

      {error, _} ->
        {:error, "git ls-files failed: #{error}"}
    end
  end

  defp filter_files(files, extensions) do
    Enum.filter(files, fn file ->
      ext = Path.extname(file)
      size = file_size_bytes(file)
      ext in extensions and size > 0 and size <= @max_file_size_bytes
    end)
  end

  defp file_size_bytes(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end

  defp process_files(user_id, _dir_path, files, chunk_size, chunk_overlap) do
    chunks_with_meta =
      Enum.flat_map(files, fn file ->
        file
        |> read_content()
        |> chunk_content(chunk_size, chunk_overlap)
        |> Enum.map(fn {chunk, line} ->
          {chunk, %{file: Path.relative_to(file, dir_path(file)), line: line}}
        end)
      end)

    # Batch embed and store
    chunks_with_meta
    |> Enum.chunk_every(50)
    |> Enum.each(fn batch ->
      texts = Enum.map(batch, fn {chunk, _meta} -> chunk end)

      case Embeddings.generate_batch(texts) do
        {:ok, embeddings} ->
          Enum.zip(batch, embeddings)
          |> Enum.each(fn {{chunk, meta}, embedding} ->
            Memories.create_memory(%{
              user_id: user_id,
              content: chunk,
              embedding: embedding,
              memory_type: "codebase_navigation",
              metadata: meta
            })
          end)

        {:error, reason} ->
          Logger.warning("Batch embedding failed: #{reason}")
      end
    end)
  end

  defp dir_path(file) do
    Path.dirname(file)
  end

  defp read_content(path) do
    size = file_size_bytes(path)

    cond do
      size > @medium_file_size_bytes ->
        # For medium files (50-500KB), take first 50KB
        {:ok, content} = :file.read_file(path)
        binary_part(content, 0, min(byte_size(content), @medium_file_embed_bytes))

      size > 0 ->
        {:ok, content} = :file.read_file(path)
        content

      true ->
        ""
    end
  end

  defp do_chunk_lines([], _acc, _chunk_size, _overlap, _line_offset, chunks) do
    Enum.reverse(chunks)
  end

  defp do_chunk_lines(lines, buffer, chunk_size, overlap, line_offset, chunks) do
    {chunk_lines, rest} = take_chunk_lines(lines, buffer, chunk_size)

    chunk_text = Enum.join(chunk_lines, "\n")
    chunk_text_size = String.length(chunk_text)

    if chunk_text_size >= chunk_size do
      # Emit completed chunk
      new_offset = line_offset + length(chunk_lines) - overlap
      new_buffer = Enum.take(chunk_lines, -overlap)

      do_chunk_lines(rest, new_buffer, chunk_size, overlap, max(new_offset, line_offset + 1), [
        {chunk_text, line_offset} | chunks
      ])
    else
      # Not enough content for a full chunk; if we have content, emit final chunk
      if chunk_text_size > 0 do
        do_chunk_lines([], [], chunk_size, overlap, line_offset, [
          {chunk_text, line_offset} | chunks
        ])
      else
        do_chunk_lines([], [], chunk_size, overlap, line_offset, chunks)
      end
    end
  end

  defp take_chunk_lines([], buffer, _max_lines), do: {buffer, []}

  defp take_chunk_lines([line | rest], buffer, max_lines) do
    new_buffer = [line | buffer]

    if length(new_buffer) >= max_lines do
      {Enum.reverse(new_buffer), rest}
    else
      take_chunk_lines(rest, new_buffer, max_lines)
    end
  end

  defp metadata_for(memory) do
    case memory.metadata do
      %{file: file, line: line} -> %{file: file, line: line}
      _ -> %{file: "(unknown)", line: 0}
    end
  end

  defp cosine_score(query_embedding, chunk_embedding) do
    dot =
      Enum.zip(query_embedding, chunk_embedding)
      |> Enum.reduce(0.0, fn {a, b}, acc -> a * b + acc end)

    norm_q = :math.sqrt(Enum.reduce(query_embedding, 0.0, fn x, acc -> x * x + acc end))
    norm_c = :math.sqrt(Enum.reduce(chunk_embedding, 0.0, fn x, acc -> x * x + acc end))

    if norm_q > 0 and norm_c > 0 do
      dot / (norm_q * norm_c)
    else
      0.0
    end
  end
end
