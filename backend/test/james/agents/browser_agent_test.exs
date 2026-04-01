defmodule James.Agents.BrowserAgentTest do
  @moduledoc "Tests for BrowserAgent using MockLLMProvider and a fake Chrome binary."
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Agents.BrowserAgent
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} =
      Accounts.create_user(%{email: "browser_agent_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "browser-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Browser Agent Test",
        agent_type: "browser"
      })

    Sessions.create_message(%{
      session_id: session.id,
      role: "user",
      content: "Navigate to example.com"
    })

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "browser task",
        risk_level: "read_only"
      })

    %{session: session, task: task}
  end

  # Creates a fake google-chrome script and prepends its dir to PATH.
  # Returns {fake_dir, old_path} for cleanup.
  defp with_fake_chrome(fun) do
    tmp = System.tmp_dir!()
    fake_dir = Path.join(tmp, "fake_chrome_#{System.unique_integer()}")
    File.mkdir_p!(fake_dir)
    chrome_path = Path.join(fake_dir, "google-chrome")
    File.write!(chrome_path, "#!/bin/sh\nexit 0\n")
    File.chmod!(chrome_path, 0o755)

    old_path = System.get_env("PATH", "")
    System.put_env("PATH", "#{fake_dir}:#{old_path}")

    try do
      fun.()
    after
      System.put_env("PATH", old_path)
      File.rm_rf!(fake_dir)
    end
  end

  describe "BrowserAgent — Chrome not found" do
    test "marks task failed when Chrome is not available" do
      %{session: session, task: task} = setup_session()

      old_path = System.get_env("PATH", "")
      # Use an empty PATH so no Chrome is found
      System.put_env("PATH", "")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "done",
           usage: %{input_tokens: 5, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      System.put_env("PATH", old_path)
      assert Tasks.get_task(task.id).status == "failed"
    end
  end

  describe "BrowserAgent — with fake Chrome" do
    test "completes successfully with fake Chrome and mock LLM" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Navigation complete.",
           usage: %{input_tokens: 15, output_tokens: 8},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "handles LLM error gracefully" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "LLM unavailable"})

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "failed"
    end

    test "executes navigate tool call" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "nav_1",
               "name" => "navigate",
               "input" => %{"url" => "https://example.com"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Page loaded successfully.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "executes click_element tool call" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "click_1",
               "name" => "click_element",
               "input" => %{"selector" => "#submit-btn"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Button clicked.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "executes get_page_content tool call" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "content_1",
               "name" => "get_page_content",
               "input" => %{}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Content extracted.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "executes run_javascript tool call" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "js_1",
               "name" => "run_javascript",
               "input" => %{"script" => "document.title"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "JS executed.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "executes screenshot_page tool call" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{"type" => "tool_use", "id" => "ss_1", "name" => "screenshot_page", "input" => %{}}
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Screenshot taken.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "executes fill_form tool call" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "form_1",
               "name" => "fill_form",
               "input" => %{"selector" => "#email", "value" => "test@example.com"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Form filled.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "handles unknown tool call gracefully" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{"type" => "tool_use", "id" => "unk_1", "name" => "unknown_action", "input" => %{}}
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Done.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      with_fake_chrome(fn ->
        {:ok, pid} = BrowserAgent.start_link(session_id: session.id, task_id: task.id)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      end)

      assert Tasks.get_task(task.id).status == "completed"
    end
  end
end
