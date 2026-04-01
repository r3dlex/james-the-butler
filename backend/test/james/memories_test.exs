defmodule James.MemoriesTest do
  use James.DataCase

  alias James.{Accounts, Memories}

  defp create_user(email \\ "mem_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_memory(user, attrs \\ %{}) do
    {:ok, memory} =
      Memories.create_memory(Map.merge(%{user_id: user.id, content: "Default memory"}, attrs))

    memory
  end

  describe "create_memory/1" do
    test "creates a memory with content and user_id" do
      user = create_user()

      assert {:ok, memory} =
               Memories.create_memory(%{user_id: user.id, content: "Remember this"})

      assert memory.user_id == user.id
      assert memory.content == "Remember this"
    end

    test "fails when user_id is missing" do
      assert {:error, changeset} = Memories.create_memory(%{content: "Orphan memory"})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when content is missing" do
      user = create_user("mem_no_content@example.com")
      assert {:error, changeset} = Memories.create_memory(%{user_id: user.id})
      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_memories/2" do
    test "returns memories for user" do
      user = create_user("list_mem@example.com")
      create_memory(user, %{content: "Mem A"})
      create_memory(user, %{content: "Mem B"})
      memories = Memories.list_memories(user.id)
      assert length(memories) == 2
    end

    test "does not return other users' memories" do
      user1 = create_user("mem_u1@example.com")
      user2 = create_user("mem_u2@example.com")
      create_memory(user1)
      memories = Memories.list_memories(user2.id)
      assert memories == []
    end

    test "respects limit option" do
      user = create_user("mem_limit@example.com")
      for i <- 1..5, do: create_memory(user, %{content: "Mem #{i}"})
      memories = Memories.list_memories(user.id, limit: 3)
      assert length(memories) == 3
    end
  end

  describe "get_memory!/1" do
    test "returns memory by id" do
      user = create_user("get_mem@example.com")
      memory = create_memory(user)
      found = Memories.get_memory!(memory.id)
      assert found.id == memory.id
    end

    test "raises Ecto.NoResultsError for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Memories.get_memory!(Ecto.UUID.generate())
      end
    end
  end

  describe "update_memory/2" do
    test "updates the content field" do
      user = create_user("update_mem@example.com")
      memory = create_memory(user, %{content: "Old content"})
      assert {:ok, updated} = Memories.update_memory(memory, %{content: "New content"})
      assert updated.content == "New content"
    end
  end

  describe "delete_memory/1" do
    test "removes the memory" do
      user = create_user("delete_mem@example.com")
      memory = create_memory(user)
      assert {:ok, _} = Memories.delete_memory(memory)

      assert_raise Ecto.NoResultsError, fn ->
        Memories.get_memory!(memory.id)
      end
    end
  end

  describe "list_memories/2 with source_session_id" do
    test "filters memories by source_session_id" do
      alias James.{Hosts, Sessions}

      user = create_user("src_sess_mem@example.com")

      {:ok, host} =
        Hosts.create_host(%{name: "mem-host-#{System.unique_integer()}", endpoint: "http://l:1"})

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Mem Session",
          agent_type: "chat"
        })

      create_memory(user, %{content: "Session memory", source_session_id: session.id})
      create_memory(user, %{content: "Unrelated memory"})

      results = Memories.list_memories(user.id, source_session_id: session.id)
      assert length(results) == 1
      assert hd(results).content == "Session memory"
    end
  end

  describe "list_memories_for_user/1" do
    test "returns all memories for a user" do
      user = create_user("all_mem_user@example.com")
      create_memory(user, %{content: "Memory A"})
      create_memory(user, %{content: "Memory B"})
      create_memory(user, %{content: "Memory C"})

      results = Memories.list_memories_for_user(user.id)
      assert length(results) == 3
    end

    test "does not return other users' memories" do
      user1 = create_user("for_user_u1@example.com")
      user2 = create_user("for_user_u2@example.com")
      create_memory(user1, %{content: "User1 memory"})

      results = Memories.list_memories_for_user(user2.id)
      assert results == []
    end

    test "returns empty list when user has no memories" do
      user = create_user("no_mem_user@example.com")
      assert Memories.list_memories_for_user(user.id) == []
    end
  end

  describe "search_similar/3" do
    test "returns memories sorted by embedding similarity" do
      user = create_user("search_sim@example.com")
      embedding = Enum.map(1..1536, fn i -> rem(i, 10) / 10.0 end)
      create_memory(user, %{content: "Similar memory", embedding: embedding})
      create_memory(user, %{content: "Other memory"})

      results = Memories.search_similar(user.id, embedding, 5)
      # At least the memory with embedding should be returned
      assert is_list(results)
      contents = Enum.map(results, & &1.content)
      assert "Similar memory" in contents
    end

    test "returns empty list when user has no memories" do
      user = create_user("search_empty@example.com")
      embedding = Enum.map(1..1536, fn _ -> 0.0 end)
      results = Memories.search_similar(user.id, embedding)
      assert results == []
    end

    test "search_similar with project_id filters to sessions in that project" do
      alias James.{Hosts, Projects, Sessions}

      user = create_user("proj_search@example.com")

      {:ok, host} =
        Hosts.create_host(%{
          name: "proj-host-#{System.unique_integer()}",
          endpoint: "http://l:1"
        })

      {:ok, project} =
        Projects.create_project(%{
          name: "My Project",
          user_id: user.id
        })

      {:ok, session_in_project} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "In Project",
          project_id: project.id,
          agent_type: "chat"
        })

      {:ok, session_outside} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Outside",
          agent_type: "chat"
        })

      embedding = Enum.map(1..1536, fn _ -> 0.5 end)

      create_memory(user, %{
        content: "Project memory",
        embedding: embedding,
        source_session_id: session_in_project.id
      })

      create_memory(user, %{
        content: "Non-project memory",
        embedding: embedding,
        source_session_id: session_outside.id
      })

      results = Memories.search_similar(user.id, embedding, 10, project_id: project.id)
      contents = Enum.map(results, & &1.content)
      assert "Project memory" in contents
      refute "Non-project memory" in contents
    end
  end

  describe "search_text/2" do
    test "returns memories matching text query" do
      user = create_user("search_text@example.com")
      create_memory(user, %{content: "Elixir is functional"})
      create_memory(user, %{content: "Phoenix is a web framework"})

      results = Memories.search_text(user.id, "Elixir")
      assert is_list(results)
      assert Enum.any?(results, fn m -> m.content =~ "Elixir" end)
      refute Enum.any?(results, fn m -> m.content =~ "Phoenix" end)
    end

    test "search is case-insensitive" do
      user = create_user("search_ci@example.com")
      create_memory(user, %{content: "User likes ELIXIR"})

      results = Memories.search_text(user.id, "elixir")
      assert length(results) == 1
    end

    test "returns empty list when no matches" do
      user = create_user("search_text_empty@example.com")
      create_memory(user, %{content: "Some unrelated content"})

      results = Memories.search_text(user.id, "quantum computing")
      assert results == []
    end

    test "does not return other users' memories" do
      user1 = create_user("search_txt_u1@example.com")
      user2 = create_user("search_txt_u2@example.com")
      create_memory(user1, %{content: "Elixir memory"})

      results = Memories.search_text(user2.id, "Elixir")
      assert results == []
    end
  end
end
