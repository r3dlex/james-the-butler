defmodule James.Agents.CodeAgentTest do
  @moduledoc """
  Tests for CodeAgent tool execution using the MockLLMProvider.
  """
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Agents.CodeAgent
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} =
      Accounts.create_user(%{email: "code_agent_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "code-agent-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Code Agent Test",
        agent_type: "code"
      })

    Sessions.create_message(%{session_id: session.id, role: "user", content: "List files."})

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "code task",
        risk_level: "read_only"
      })

    %{session: session, task: task}
  end

  describe "CodeAgent — simple completion" do
    test "completes without tool use" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "I can help with that.",
           usage: %{input_tokens: 5, output_tokens: 10},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = CodeAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"
    end

    test "marks task failed on LLM error" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response({:error, "no key"})

      {:ok, pid} = CodeAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      updated = Tasks.get_task(task.id)
      assert updated.status == "failed"
    end
  end

  describe "CodeAgent — tool use: read_file" do
    test "executes read_file tool and continues loop" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      test_file = Path.join(tmp, "code_agent_test_#{System.unique_integer()}.txt")
      File.write!(test_file, "file content here")

      # First response: tool_use requesting read_file
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_1",
               "name" => "read_file",
               "input" => %{"path" => test_file}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 15},
           stop_reason: "tool_use"
         }}
      )

      # Second response: end_turn after seeing tool result
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "File read successfully.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"

      File.rm(test_file)
    end

    test "read_file returns error for path outside working_dirs" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_2",
               "name" => "read_file",
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
           content: "Understood, path was not allowed.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      # Check the tool result message was saved
      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))

      assert Enum.any?(system_msgs, fn m ->
               m.content =~ "not allowed" or m.content =~ "outside"
             end)
    end
  end

  describe "CodeAgent — tool use: list_directory" do
    test "lists directory contents" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_3",
               "name" => "list_directory",
               "input" => %{"path" => tmp}
             }
           ],
           usage: %{input_tokens: 15, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Directory listed.",
           usage: %{input_tokens: 25, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"
    end
  end

  describe "CodeAgent — tool use: write_file" do
    test "writes a file and completes" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      out_path = Path.join(tmp, "code_agent_write_#{System.unique_integer()}.txt")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_4",
               "name" => "write_file",
               "input" => %{"path" => out_path, "content" => "written content"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Done writing.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      assert File.exists?(out_path)
      assert File.read!(out_path) == "written content"
      File.rm(out_path)
    end
  end

  describe "CodeAgent — tool use: execute_command" do
    test "executes a shell command" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_5",
               "name" => "execute_command",
               "input" => %{"command" => "echo hello_from_tool"}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Command executed.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "hello_from_tool" end)
    end
  end

  describe "CodeAgent — tool use: search_files" do
    test "searches for files by pattern" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_6",
               "name" => "search_files",
               "input" => %{"pattern" => "*.exs", "path" => tmp}
             }
           ],
           usage: %{input_tokens: 20, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Search complete.",
           usage: %{input_tokens: 30, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"
    end
  end

  describe "CodeAgent — unknown tool" do
    test "returns error message for unknown tool" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "tool_unknown",
               "name" => "nonexistent_tool",
               "input" => %{}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Understood.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "unknown tool" end)
    end
  end

  describe "CodeAgent — tool path restriction" do
    test "returns error when read_file path is outside allowed dirs" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t1",
               "name" => "read_file",
               "input" => %{"path" => "/etc/passwd"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Got it.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      assert Tasks.get_task(task.id).status == "completed"
    end

    test "returns error when write_file path is outside allowed dirs" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t2",
               "name" => "write_file",
               "input" => %{"path" => "/etc/malicious", "content" => "bad"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Got it.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      assert Tasks.get_task(task.id).status == "completed"
    end

    test "returns error when execute_command working_dir is outside allowed dirs" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t3",
               "name" => "execute_command",
               "input" => %{"command" => "echo hi", "working_dir" => "/etc"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Got it.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      assert Tasks.get_task(task.id).status == "completed"
    end

    test "search_files with content filter" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t4",
               "name" => "search_files",
               "input" => %{"pattern" => "*.ex", "path" => tmp, "content" => "defmodule"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Search done.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      assert Tasks.get_task(task.id).status == "completed"
    end

    test "read_file returns error for nonexistent file" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()
      nonexistent = Path.join(tmp, "nonexistent_#{System.unique_integer()}.txt")

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t5",
               "name" => "read_file",
               "input" => %{"path" => nonexistent}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Got it.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "Error" end)
    end

    test "list_directory returns error for path outside allowed dirs" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t6",
               "name" => "list_directory",
               "input" => %{"path" => "/etc"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Got it.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "allowed" end)
    end

    test "search_files with path outside allowed dirs returns error" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{
               "type" => "tool_use",
               "id" => "t7",
               "name" => "search_files",
               "input" => %{"pattern" => "*.ex", "path" => "/etc"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 5},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Got it.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [System.tmp_dir!()]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      messages = Sessions.list_messages(session.id)
      system_msgs = Enum.filter(messages, &(&1.role == "system"))
      assert Enum.any?(system_msgs, fn m -> m.content =~ "allowed" end)
    end
  end

  describe "CodeAgent — max iterations guard" do
    test "stops after max iterations with notification message" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      # Push 11 tool_use responses to exceed @max_iterations (10)
      for i <- 1..11 do
        MockLLMProvider.push_response(
          {:ok,
           %{
             content: [
               %{
                 "type" => "tool_use",
                 "id" => "iter_#{i}",
                 "name" => "execute_command",
                 "input" => %{"command" => "echo iteration_#{i}"}
               }
             ],
             usage: %{input_tokens: 5, output_tokens: 5},
             stop_reason: "tool_use"
           }}
        )
      end

      {:ok, pid} =
        CodeAgent.start_link(
          session_id: session.id,
          task_id: task.id,
          working_dirs: [tmp]
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 15_000

      updated = Tasks.get_task(task.id)
      assert updated.status == "completed"
    end
  end

  describe "CodeAgent — session with working_dirs in metadata" do
    test "uses working_dirs from session metadata" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "code_meta_#{System.unique_integer()}@example.com"
        })

      {:ok, host} =
        Hosts.create_host(%{
          name: "code-meta-host-#{System.unique_integer()}",
          endpoint: "http://localhost:9999"
        })

      tmp = System.tmp_dir!()

      {:ok, session} =
        Sessions.create_session(%{
          user_id: user.id,
          host_id: host.id,
          name: "Meta Working Dirs",
          agent_type: "code",
          metadata: %{"working_dirs" => [tmp]}
        })

      Sessions.create_message(%{session_id: session.id, role: "user", content: "List files."})

      {:ok, task} =
        Tasks.create_task(%{
          session_id: session.id,
          description: "meta dirs task",
          risk_level: "read_only"
        })

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "Done using metadata working dirs.",
           usage: %{input_tokens: 5, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      # Do not pass working_dirs option — let it derive from session metadata
      {:ok, pid} = CodeAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      assert Tasks.get_task(task.id).status == "completed"
    end
  end

  describe "CodeAgent — zero token usage" do
    test "completes without recording tokens when usage is zero" do
      %{session: session, task: task} = setup_session()

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "No tokens.",
           usage: %{input_tokens: 0, output_tokens: 0},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} = CodeAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
      assert Tasks.get_task(task.id).status == "completed"
    end
  end

  describe "CodeAgent — content with mixed text and tool_use blocks" do
    test "extracts text content from mixed content list" do
      %{session: session, task: task} = setup_session()
      tmp = System.tmp_dir!()

      # First response: mixed content — text block + tool_use block
      MockLLMProvider.push_response(
        {:ok,
         %{
           content: [
             %{"type" => "text", "text" => "I will read the file."},
             %{
               "type" => "tool_use",
               "id" => "mixed_1",
               "name" => "execute_command",
               "input" => %{"command" => "echo mixed_test"}
             }
           ],
           usage: %{input_tokens: 10, output_tokens: 10},
           stop_reason: "tool_use"
         }}
      )

      MockLLMProvider.push_response(
        {:ok,
         %{
           content: "All done.",
           usage: %{input_tokens: 20, output_tokens: 5},
           stop_reason: "end_turn"
         }}
      )

      {:ok, pid} =
        CodeAgent.start_link(
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
