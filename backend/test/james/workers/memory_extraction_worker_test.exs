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
  end
end
