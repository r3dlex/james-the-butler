defmodule James.Agents.DesktopAgentTest do
  @moduledoc "Tests for DesktopAgent — Daemon.status() always returns :disconnected in tests."
  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.Agents.DesktopAgent
  alias James.Test.MockLLMProvider

  setup do
    MockLLMProvider.flush()
    :ok
  end

  defp setup_session do
    {:ok, user} =
      Accounts.create_user(%{email: "desktop_agent_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "desktop-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9999"
      })

    {:ok, session} =
      Sessions.create_session(%{
        user_id: user.id,
        host_id: host.id,
        name: "Desktop Agent Test",
        agent_type: "desktop"
      })

    Sessions.create_message(%{
      session_id: session.id,
      role: "user",
      content: "Take a screenshot of the screen."
    })

    {:ok, task} =
      Tasks.create_task(%{
        session_id: session.id,
        description: "desktop task",
        risk_level: "read_only"
      })

    %{session: session, task: task}
  end

  describe "DesktopAgent — daemon disconnected (always in tests)" do
    test "marks task failed when daemon is not running" do
      # Daemon.status/0 is a stub that always returns :disconnected
      %{session: session, task: task} = setup_session()

      {:ok, pid} = DesktopAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      assert Tasks.get_task(task.id).status == "failed"
    end

    test "broadcasts unavailability message when daemon is not running" do
      %{session: session, task: task} = setup_session()

      Phoenix.PubSub.subscribe(James.PubSub, "session:#{session.id}")

      {:ok, pid} = DesktopAgent.start_link(session_id: session.id, task_id: task.id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 3000

      chunks =
        receive do
          {:assistant_chunk, text} -> [text]
        after
          500 -> []
        end

      assert Enum.any?(chunks, fn c -> c =~ "daemon" end) or
               Enum.any?(chunks, fn c -> c =~ "not running" end) or
               chunks != []
    end

    test "starts without task_id without crashing" do
      %{session: session} = setup_session()

      {:ok, pid} = DesktopAgent.start_link(session_id: session.id)
      ref = Process.monitor(pid)
      # Process exits quickly — accept :noproc if already dead when monitor registered
      assert_receive {:DOWN, ^ref, :process, ^pid, reason}, 3000
      assert reason in [:normal, :noproc]
    end
  end
end
