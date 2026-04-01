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

  describe "SecurityAgent — scan_file tool" do
    test "agent defines scan_file tool and reads file via tool loop" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      test_file = Path.join(tmp, "scan_test_#{System.unique_integer()}.ex")
      File.write!(test_file, "def risky, do: :os.cmd(~c\"rm -rf /\")")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "scan_file_1",
               "name" => "scan_file",
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
           content: "Scan complete.",
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

    test "scan_file returns error for disallowed path" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "scan_file_2",
               "name" => "scan_file",
               "input" => %{"path" => "/etc/passwd"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "OK.",
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

      assert Tasks.get_task(task.id).status == "completed"
    end
  end

  describe "SecurityAgent — scan_directory tool" do
    test "lists files matching pattern via Path.wildcard" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "scan_dir_1",
               "name" => "scan_directory",
               "input" => %{"path" => tmp, "pattern" => "*.ex"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Directory scanned.",
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

  describe "SecurityAgent — check_dependencies tool" do
    test "reads manifest file and returns content" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      manifest = Path.join(tmp, "mix_#{System.unique_integer()}.exs")
      File.write!(manifest, "{:phoenix, \"~> 1.7\"}")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "check_deps_1",
               "name" => "check_dependencies",
               "input" => %{"manifest_path" => manifest}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Dependencies checked.",
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
      File.rm(manifest)
    end
  end

  describe "SecurityAgent — generate_findings tool" do
    test "saves structured findings as system message with required fields" do
      %{session: session, task: task} = setup_session()

      findings_json =
        Jason.encode!([
          %{
            severity: "high",
            description: "Command injection risk",
            location: "lib/runner.ex:15",
            remediation: "Sanitize user input before passing to System.cmd/2"
          },
          %{
            severity: "medium",
            description: "Hardcoded secret",
            location: "config/prod.exs:5",
            remediation: "Move secret to environment variable"
          }
        ])

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "gen_findings_1",
               "name" => "generate_findings",
               "input" => %{"findings_json" => findings_json}
             }
           ],
           usage: %{input_tokens: 30, output_tokens: 15},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Findings saved.",
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

      assert Enum.any?(system_msgs, fn m ->
               m.content =~ "Command injection risk" and
                 m.content =~ "HIGH" and
                 m.content =~ "lib/runner.ex:15"
             end)
    end

    test "generate_findings handles invalid JSON gracefully" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "gen_findings_2",
               "name" => "generate_findings",
               "input" => %{"findings_json" => "not valid json {{"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Handled.",
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

      # Should complete without crashing
      assert Tasks.get_task(task.id).status == "completed"
    end
  end

  describe "SecurityAgent — multi-tool accumulation" do
    test "accumulates findings across multiple tool calls" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      test_file = Path.join(tmp, "multi_scan_#{System.unique_integer()}.ex")
      File.write!(test_file, "def bad, do: :os.cmd(~c\"ls\")")

      # Step 1: scan_file tool call
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "multi_1",
               "name" => "scan_file",
               "input" => %{"path" => test_file}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      # Step 2: generate_findings tool call
      findings_json =
        Jason.encode!([
          %{
            severity: "low",
            description: "Unsafe OS call",
            location: test_file,
            remediation: "Use safe wrapper"
          }
        ])

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "multi_2",
               "name" => "generate_findings",
               "input" => %{"findings_json" => findings_json}
             }
           ],
           usage: %{input_tokens: 30, output_tokens: 15},
           stop_reason: "tool_use"
         }}
      )

      # Final text response
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Security scan complete. 1 finding.",
           usage: %{input_tokens: 40, output_tokens: 8},
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

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))

      assert Enum.any?(system_msgs, fn m -> m.content =~ "Unsafe OS call" end)

      File.rm(test_file)
    end
  end
end
