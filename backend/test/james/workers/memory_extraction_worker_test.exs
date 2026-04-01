defmodule James.Workers.MemoryExtractionWorkerTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions}
  alias James.Workers.MemoryExtractionWorker

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
end
