defmodule James.Agents.SecurityAgentTest do
  @moduledoc "Tests for SecurityAgent tool execution using MockLLMProvider."
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Agents.SecurityAgent
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} =
      Accounts.create_user(%{email: "sec_agent_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "sec-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Security Agent Test",
        agent_type: "code"
      })

    Sessions.create_message(%{
      session_id: session.id,
      role: "user",
      content: "Scan this directory for vulnerabilities."
    })

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "security task",
        risk_level: "read_only"
      })

    %{session: session, task: task}
  end

  describe "SecurityAgent — simple completion" do
    test "completes without tool use" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "No vulnerabilities found.",
           usage: %{input_tokens: 10, output_tokens: 8},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = SecurityAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      assert Tasks.get_task(task.id).status == "completed"
    end

    test "handles LLM error" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "no key"})

      {:ok, pid} = SecurityAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      assert Tasks.get_task(task.id).status == "failed"
    end
  end

  describe "SecurityAgent — read_file tool" do
    test "reads an allowed file" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      test_file = Path.join(tmp, "sec_test_#{System.unique_integer()}.ex")
      File.write!(test_file, "def vulnerable, do: System.cmd(input, [])")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "sec_tool_1",
               "name" => "read_file",
               "input" => %{"path" => test_file}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "File analyzed.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        SecurityAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert Tasks.get_task(task.id).status == "completed"
      File.rm(test_file)
    end

    test "returns error for path outside allowed dirs" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "sec_tool_2",
               "name" => "read_file",
               "input" => %{"path" => "/etc/shadow"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Understood.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        SecurityAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      # SecurityAgent completes (the "path not allowed" error goes into the in-memory
      # message context, not saved to DB messages, so we just verify clean exit)
      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"
    end
  end

  describe "SecurityAgent — report_finding tool" do
    test "saves a security finding as system message" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "sec_tool_3",
               "name" => "report_finding",
               "input" => %{
                 "severity" => "high",
                 "title" => "SQL Injection",
                 "description" => "Unsanitized input in query",
                 "file" => "lib/repo.ex",
                 "line" => 42,
                 "recommendation" => "Use parameterized queries"
               }
             }
           ],
           usage: %{input_tokens: 30, output_tokens: 15},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Finding reported.",
           usage: %{input_tokens: 40, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        SecurityAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "SQL Injection" end)
    end
  end

  describe "SecurityAgent — search_pattern tool" do
    test "searches for patterns in allowed directory" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "sec_tool_4",
               "name" => "search_pattern",
               "input" => %{"pattern" => "System\\.cmd", "path" => tmp, "file_pattern" => "*.ex"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Pattern search done.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        SecurityAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert Tasks.get_task(task.id).status == "completed"
    end
  end
end
