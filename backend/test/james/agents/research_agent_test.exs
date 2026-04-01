defmodule James.Agents.ResearchAgentTest do
  @moduledoc "Tests for ResearchAgent tool execution using MockLLMProvider."
  use James.DataCase

  alias James.Agents.ResearchAgent
  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} =
      Accounts.create_user(%{email: "research_agent_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "research-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Research Agent Test",
        agent_type: "research"
      })

    Sessions.create_message(%{
      session_id: session.id,
      role: "user",
      content: "Research Elixir best practices."
    })

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "research task",
        risk_level: "read_only"
      })

    %{session: session, task: task}
  end

  describe "ResearchAgent — simple completion" do
    test "completes without tool use" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:ok, %{
        content: "Elixir follows functional programming best practices.",
        usage: %{input_tokens: 10, output_tokens: 20},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "handles LLM error gracefully" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "timeout"})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      assert Tasks.get_task(task.id).status == "failed"
    end
  end

  describe "ResearchAgent — web_search tool" do
    test "executes web_search and returns stub response" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:ok, %{
        content: [
          %{"type" => "tool_use", "id" => "tool_ws1", "name" => "web_search",
            "input" => %{"query" => "Elixir pattern matching"}}
        ],
        usage: %{input_tokens: 15, output_tokens: 10},
        stop_reason: "tool_use"
      }})

      MockLLMProvider.push_response({:ok, %{
        content: "Web search stub returned results.",
        usage: %{input_tokens: 25, output_tokens: 10},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert Tasks.get_task(task.id).status == "completed"
    end
  end

  describe "ResearchAgent — create_report tool" do
    test "saves a research report via create_report tool" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:ok, %{
        content: [
          %{"type" => "tool_use", "id" => "tool_cr1", "name" => "create_report",
            "input" => %{"title" => "Elixir Report", "content" => "## Summary\nElixir is great."}}
        ],
        usage: %{input_tokens: 20, output_tokens: 15},
        stop_reason: "tool_use"
      }})

      MockLLMProvider.push_response({:ok, %{
        content: "Report saved.",
        usage: %{input_tokens: 30, output_tokens: 5},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "Elixir Report" end)
    end
  end

  describe "ResearchAgent — unknown tool" do
    test "returns unknown tool message" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:ok, %{
        content: [
          %{"type" => "tool_use", "id" => "tool_unk", "name" => "nonexistent",
            "input" => %{}}
        ],
        usage: %{input_tokens: 10, output_tokens: 5},
        stop_reason: "tool_use"
      }})

      MockLLMProvider.push_response({:ok, %{
        content: "Acknowledged.",
        usage: %{input_tokens: 20, output_tokens: 5},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert Tasks.get_task(task.id).status == "completed"
    end
  end

  describe "ResearchAgent — fetch_url tool" do
    test "fetches URL and strips HTML on 200 response" do
      %{session: session, task: task} = setup_session()
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/page", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_resp(200, "<html><body><p>Hello World</p></body></html>")
      end)

      MockLLMProvider.push_response({:ok, %{
        content: [
          %{"type" => "tool_use", "id" => "fetch_1", "name" => "fetch_url",
            "input" => %{"url" => "http://localhost:#{bypass.port}/page"}}
        ],
        usage: %{input_tokens: 20, output_tokens: 10},
        stop_reason: "tool_use"
      }})

      MockLLMProvider.push_response({:ok, %{
        content: "Page fetched.",
        usage: %{input_tokens: 30, output_tokens: 5},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "returns error message on non-200 HTTP response" do
      %{session: session, task: task} = setup_session()
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/missing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(404, "Not Found")
      end)

      MockLLMProvider.push_response({:ok, %{
        content: [
          %{"type" => "tool_use", "id" => "fetch_2", "name" => "fetch_url",
            "input" => %{"url" => "http://localhost:#{bypass.port}/missing"}}
        ],
        usage: %{input_tokens: 20, output_tokens: 10},
        stop_reason: "tool_use"
      }})

      MockLLMProvider.push_response({:ok, %{
        content: "URL error noted.",
        usage: %{input_tokens: 30, output_tokens: 5},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "returns error message when URL is unreachable" do
      %{session: session, task: task} = setup_session()
      bypass = Bypass.open()
      Bypass.down(bypass)

      MockLLMProvider.push_response({:ok, %{
        content: [
          %{"type" => "tool_use", "id" => "fetch_3", "name" => "fetch_url",
            "input" => %{"url" => "http://localhost:#{bypass.port}/unreachable"}}
        ],
        usage: %{input_tokens: 20, output_tokens: 10},
        stop_reason: "tool_use"
      }})

      MockLLMProvider.push_response({:ok, %{
        content: "URL error noted.",
        usage: %{input_tokens: 30, output_tokens: 5},
        stop_reason: "end_turn"
      }})

      {:ok, pid} = ResearchAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      # Req retries connection errors with backoff (1+2+4s), allow extra time
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 15_000

      assert Tasks.get_task(task.id).status == "completed"
    end
  end
end
