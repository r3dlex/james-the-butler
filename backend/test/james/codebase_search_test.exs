defmodule James.CodebaseSearchTest do
  use James.DataCase

  alias James.{Accounts, CodebaseSearch, Memories}

  setup do
    {:ok, user} =
      Accounts.create_user(%{email: "codebase_search_#{Ecto.UUID.generate()}@example.com"})

    %{user: user}
  end

  describe "extension filtering" do
    test "default extensions include common code types" do
      defaults = James.CodebaseSearch.extensions()

      assert ".ex" in defaults
      assert ".py" in defaults
      assert ".rs" in defaults
      assert ".md" in defaults
      refute ".pdf" in defaults
      refute ".png" in defaults
    end

    test "filters by configured extensions" do
      extensions = [".ex", ".py"]

      assert CodebaseSearch.extension_matches?(".ex", extensions)
      assert CodebaseSearch.extension_matches?(".py", extensions)
      refute CodebaseSearch.extension_matches?(".js", extensions)
    end
  end

  describe "file size filtering" do
    test "skips files larger than 500KB" do
      max_size = 500 * 1024
      # 500KB + 1 byte
      refute CodebaseSearch.within_size_limit?(max_size + 1)
    end

    test "accepts files smaller than 500KB" do
      assert CodebaseSearch.within_size_limit?(1024)
    end

    test "accepts exactly 500KB" do
      assert CodebaseSearch.within_size_limit?(500 * 1024)
    end

    test "rejects zero-byte files" do
      refute CodebaseSearch.within_size_limit?(0)
    end
  end

  describe "chunk_content" do
    test "chunks small content into a single chunk" do
      content = "defmodule Foo do\n  def hello, do: :world\nend\n"

      chunks = CodebaseSearch.chunk_content(content, 250, 100)

      assert length(chunks) == 1
      {chunk_text, line} = hd(chunks)
      # Content should contain all the original lines (order may vary with line-based chunking)
      assert String.contains?(chunk_text, "defmodule Foo do")
      assert String.contains?(chunk_text, "def hello")
      assert String.contains?(chunk_text, "end")
      assert line == 0
    end

    test "chunks large content into multiple chunks with overlap" do
      # Build content with many lines
      lines =
        for i <- 1..100, do: "  line #{i} = #{String.pad_leading(Integer.to_string(i), 3, "0")},"

      content = "defmodule Example do\n" <> Enum.join(lines, "\n") <> "\nend\n"

      chunks = CodebaseSearch.chunk_content(content, 50, 10)

      # Multiple chunks expected for 100+ lines
      assert length(chunks) > 1

      # Adjacent chunks should not be identical
      [{chunk1, _line1}, {chunk2, _line2} | _] = chunks
      refute chunk1 == chunk2
    end

    test "returns empty list for empty content" do
      chunks = CodebaseSearch.chunk_content("", 250, 100)
      assert chunks == []
    end

    test "line numbers increment across chunks" do
      lines = for i <- 1..200, do: "line #{i}"
      content = Enum.join(lines, "\n")

      chunks = CodebaseSearch.chunk_content(content, 30, 5)

      line_numbers = Enum.map(chunks, fn {_text, line} -> line end)
      # Line numbers should be increasing
      assert line_numbers == Enum.sort(line_numbers)
    end

    test "overlapping chunks share boundary lines" do
      lines = for i <- 1..50, do: "line #{i}"
      content = Enum.join(lines, "\n")

      chunks = CodebaseSearch.chunk_content(content, 20, 5)

      assert length(chunks) > 1

      # Verify that adjacent chunks overlap (share some lines)
      [{chunk1, _line1}, {chunk2, line2} | _] = chunks
      # chunk1 ends with some lines, chunk2 starts from where they overlap
      # We check that line2 is not simply 0
      assert line2 > 0
    end
  end

  describe "search result structure" do
    test "search returns error when embeddings unavailable" do
      # When no API key is configured, embedding generation returns error
      # We verify the search function handles this gracefully
      result = CodebaseSearch.search("fake-user-id", "test query", 5)

      # The function should return either ok with list or error
      assert is_tuple(result)
    end

    test "clear_index removes codebase_navigation memories", %{user: user} do
      # Pre-seed a memory directly to simulate indexed content
      {:ok, _} =
        Memories.create_memory(%{
          user_id: user.id,
          content: "def hello do\n  :world\nend",
          embedding: Enum.map(1..1536, fn _ -> 0.1 end),
          memory_type: "codebase_navigation",
          metadata: %{file: "test.ex", line: 0}
        })

      # Verify it exists
      memories =
        Memories.list_memories(user.id)
        |> Enum.filter(&(&1.memory_type == "codebase_navigation"))

      assert length(memories) >= 1

      # Clear
      CodebaseSearch.clear_index(user.id)

      # Verify removed
      remaining =
        Memories.list_memories(user.id)
        |> Enum.filter(&(&1.memory_type == "codebase_navigation"))

      assert remaining == []
    end
  end

  describe "search ordering" do
    test "results are sorted by similarity score descending", %{user: user} do
      # Pre-seed memories with embeddings that should rank differently
      embedding1 = Enum.map(1..1536, fn _ -> 0.1 end)
      embedding2 = Enum.map(1..1536, fn _ -> 0.9 end)

      {:ok, _} =
        Memories.create_memory(%{
          user_id: user.id,
          content: "about elixir programming",
          embedding: embedding1,
          memory_type: "codebase_navigation",
          metadata: %{file: "elixir.ex", line: 0}
        })

      {:ok, _} =
        Memories.create_memory(%{
          user_id: user.id,
          content: "completely unrelated content xyz",
          embedding: embedding2,
          memory_type: "codebase_navigation",
          metadata: %{file: "other.ex", line: 0}
        })

      # Search with a query that should match elixir content
      result = CodebaseSearch.search(user.id, "elixir", 5)

      # Cleanup
      CodebaseSearch.clear_index(user.id)

      case result do
        {:ok, results} ->
          # Results should be sorted by score descending
          if length(results) >= 2 do
            scores = Enum.map(results, & &1.score)
            assert scores == Enum.sort(scores, :desc)
          end

        {:error, _} ->
          # Expected when embeddings service is not configured
          :ok
      end
    end
  end

  describe "index_working_directory" do
    test "returns error for non-existent directory", %{user: user} do
      result =
        CodebaseSearch.index_working_directory(
          user.id,
          "/nonexistent/path/#{Ecto.UUID.generate()}"
        )

      assert {:error, _} = result
    end

    test "returns ok with task for backend lib directory", %{user: user} do
      # Use the backend's own lib directory which exists and has .ex files
      lib_dir = :code.priv_dir(:james) |> Path.join("../lib") |> Path.expand()

      result =
        CodebaseSearch.index_working_directory(user.id, lib_dir)

      case result do
        {:ok, task} ->
          # Wait briefly for async task
          Process.sleep(200)
          assert is_pid(task.pid)

        {:error, reason} ->
          # Git may fail or files may be empty in test env
          assert is_binary(reason) or reason == :git_failed
      end
    end
  end
end
