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
end
