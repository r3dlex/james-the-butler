defmodule James.Workers.MemoryExtractionWorkerTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Memories, Sessions}
  alias James.Test.MockLLMProvider
  alias James.Workers.MemoryExtractionWorker

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp create_user do
    {:ok, user} =
      Accounts.create_user(%{email: "mem_worker_#{System.unique_integer()}@example.com"})

    user
  end

  defp create_session(user) do
    {:ok, host} =
      Hosts.create_host(%{
        name: "mem-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9000"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Memory Session"})

    session
  end

  describe "perform/1 — too few messages" do
    test "returns :ok without calling Anthropic when session has 0 messages" do
      user = create_user()
      session = create_session(user)

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)
    end

    test "returns :ok without calling Anthropic when session has only 1 message" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "Just one message",
        token_count: 5,
        model: "claude-sonnet-4-20250514"
      })

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)
    end
  end

  describe "perform/1 — Anthropic not configured" do
    setup do
      original_key = Application.get_env(:james, :anthropic_api_key)
      original_env = System.get_env("ANTHROPIC_API_KEY")

      Application.delete_env(:james, :anthropic_api_key)
      System.delete_env("ANTHROPIC_API_KEY")

      on_exit(fn ->
        case original_key do
          nil -> Application.delete_env(:james, :anthropic_api_key)
          v -> Application.put_env(:james, :anthropic_api_key, v)
        end

        case original_env do
          nil -> System.delete_env("ANTHROPIC_API_KEY")
          v -> System.put_env("ANTHROPIC_API_KEY", v)
        end
      end)

      :ok
    end

    test "returns :ok even when Anthropic API key is missing and session has messages" do
      user = create_user()
      session = create_session(user)

      Enum.each(1..3, fn i ->
        Sessions.create_message(%{
          session_id: session.id,
          role: if(rem(i, 2) == 0, do: "assistant", else: "user"),
          content: "Message #{i}",
          token_count: 5,
          model: "claude-sonnet-4-20250514"
        })
      end)

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)
    end
  end

  describe "perform/1 — with mock LLM provider" do
    test "extracts and stores memories from valid JSON array response" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "I use Elixir."})

      Sessions.create_message(%{
        session_id: session.id,
        role: "assistant",
        content: "Great choice!"
      })

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User prefers Elixir programming language"]),
           usage: %{input_tokens: 30, output_tokens: 10}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)
      assert Enum.any?(memories, fn m -> m.content =~ "Elixir" end)
    end

    test "handles empty JSON array — stores no memories" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "Hi"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Hello!"})

      MockLLMProvider.push_response(
        {:ok, %{content: "[]", usage: %{input_tokens: 10, output_tokens: 2}}}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      assert Memories.list_memories(user.id) == []
    end

    test "handles JSON array embedded in text" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "I love Erlang."})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Nice!"})

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(Here are the memories: ["User loves Erlang"]\n),
           usage: %{input_tokens: 20, output_tokens: 8}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)
      assert Enum.any?(memories, fn m -> m.content =~ "Erlang" end)
    end

    test "handles non-parseable text gracefully (no crash, no memories)" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "Hello"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Hi!"})

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Nothing worth remembering here.",
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      assert Memories.list_memories(user.id) == []
    end

    test "handles LLM provider error gracefully" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "test"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "ok"})

      MockLLMProvider.push_response({:error, "provider error"})

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)
    end

    test "skips duplicate memory — same content stored only once" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "I love Elixir."})

      Sessions.create_message(%{
        session_id: session.id,
        role: "assistant",
        content: "Great language!"
      })

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User loves Elixir"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      # Run again with same content — should deduplicate
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User loves Elixir"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)
      elixir_memories = Enum.filter(memories, fn m -> m.content == "User loves Elixir" end)
      assert length(elixir_memories) == 1
    end

    test "stores memory with embedding when embedding generation runs (Bumblebee fallback stores zeros)" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "I work in Phoenix."
      })

      Sessions.create_message(%{
        session_id: session.id,
        role: "assistant",
        content: "Phoenix is great!"
      })

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User works with Phoenix framework"]),
           usage: %{input_tokens: 15, output_tokens: 8}
         }}
      )

      # Bumblebee falls back to zeros when unavailable, so embedding is always stored
      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)
      phoenix_mem = Enum.find(memories, fn m -> m.content =~ "Phoenix" end)
      assert phoenix_mem
      # Embedding is always a 384-element vector (zeros when Bumblebee unavailable)
      assert embedded = phoenix_mem.embedding
      assert is_struct(embedded, Pgvector)
      assert length(Pgvector.to_list(embedded)) == 384
    end

    test "extracts memory_type from map-format response and stores it correctly" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "The codebase uses Elixir."
      })

      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "I see."})

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s([{"type": "codebase_fact", "content": "Codebase is written in Elixir"}]),
           usage: %{input_tokens: 20, output_tokens: 10}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)
      assert Enum.any?(memories, fn m -> m.content == "Codebase is written in Elixir" end)

      saved_memory = Enum.find(memories, fn m -> m.content == "Codebase is written in Elixir" end)
      assert saved_memory.memory_type == "codebase_fact"
    end

    test "extracts memory_type from mixed-type response and stores each type correctly" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "I prefer dark mode."
      })

      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Got it."})

      MockLLMProvider.push_response(
        {:ok,
         %{
           content:
             ~s([{"type": "user_preference", "content": "User prefers dark mode"}, {"type": "codebase_navigation", "content": "Settings are in config/"}]),
           usage: %{input_tokens: 20, output_tokens: 10}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)

      dark_mode = Enum.find(memories, fn m -> m.content == "User prefers dark mode" end)
      assert dark_mode.memory_type == "user_preference"

      settings = Enum.find(memories, fn m -> m.content == "Settings are in config/" end)
      assert settings.memory_type == "codebase_navigation"
    end

    test "backward compatible: legacy string-only response stores as general memory_type" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "Hello"})
      Sessions.create_message(%{session_id: session.id, role: "assistant", content: "Hi!"})

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User said hello"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}
      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)
      assert Enum.any?(memories, fn m -> m.content == "User said hello" end)

      saved_memory = Enum.find(memories, fn m -> m.content == "User said hello" end)
      assert saved_memory.memory_type == "general"
    end

    test "is idempotent — running twice stores no duplicates" do
      user = create_user()
      session = create_session(user)

      Sessions.create_message(%{session_id: session.id, role: "user", content: "I like Rust."})

      Sessions.create_message(%{
        session_id: session.id,
        role: "assistant",
        content: "Rust is powerful!"
      })

      job = %Oban.Job{args: %{"session_id" => session.id, "user_id" => user.id}}

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User likes Rust programming language"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      assert :ok = MemoryExtractionWorker.perform(job)

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["User likes Rust programming language"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      assert :ok = MemoryExtractionWorker.perform(job)

      memories = Memories.list_memories(user.id)

      rust_count =
        Enum.count(memories, fn m -> m.content == "User likes Rust programming language" end)

      assert rust_count == 1
    end

    test "processes only new messages since last extraction (delta tracking)" do
      user = create_user()
      session = create_session(user)

      {:ok, msg1} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "user",
          content: "First message"
        })

      {:ok, _msg2} =
        Sessions.create_message(%{
          session_id: session.id,
          role: "assistant",
          content: "First reply"
        })

      # First extraction
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["Memory from first batch"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      job1 = %Oban.Job{
        args: %{
          "session_id" => session.id,
          "user_id" => user.id,
          "last_extracted_message_id" => nil
        }
      }

      assert :ok = MemoryExtractionWorker.perform(job1)
      memories_after_first = Memories.list_memories(user.id)
      assert memories_after_first != []

      # Add new messages after first extraction
      Sessions.create_message(%{
        session_id: session.id,
        role: "user",
        content: "Second message"
      })

      Sessions.create_message(%{
        session_id: session.id,
        role: "assistant",
        content: "Second reply"
      })

      # Second extraction with last_extracted_message_id set to msg1.id
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: ~s(["Memory from second batch"]),
           usage: %{input_tokens: 10, output_tokens: 5}
         }}
      )

      job2 = %Oban.Job{
        args: %{
          "session_id" => session.id,
          "user_id" => user.id,
          "last_extracted_message_id" => msg1.id
        }
      }

      assert :ok = MemoryExtractionWorker.perform(job2)

      memories_after_second = Memories.list_memories(user.id)
      # Should have memories from both batches
      assert Enum.any?(memories_after_second, fn m -> m.content =~ "first batch" end)
      assert Enum.any?(memories_after_second, fn m -> m.content =~ "second batch" end)
    end
  end
end
