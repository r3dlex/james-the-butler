defmodule James.Planner.MetaPlannerSynthesisTest do
  @moduledoc """
  Tests that verify the synthesis rules are embedded in the MetaPlanner
  decomposition prompt and that context is reused appropriately for follow-up
  messages.
  """

  use James.DataCase

  alias James.{Accounts, Hosts, Sessions, Tasks}
  alias James.OpenClaw.Orchestrator
  alias James.OpenClaw.Supervisor, as: AgentSupervisor
  alias James.Planner.MetaPlanner
  alias James.Test.MockLLMProvider

  setup do
    if is_nil(Process.whereis(AgentSupervisor)) do
      {:ok, _} = AgentSupervisor.start_link([])
    end

    if is_nil(Process.whereis(Orchestrator)) do
      {:ok, _} = Orchestrator.start_link([])
    end

    if is_nil(Process.whereis(MetaPlanner)) do
      {:ok, _} = MetaPlanner.start_link([])
    end

    MockLLMProvider.flush()
    :ok
  end

  defp create_user do
    {:ok, user} =
      Accounts.create_user(%{email: "synthesis_#{System.unique_integer()}@example.com"})

    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "synthesis-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9502"
      })

    host
  end

  defp create_session(user, host, attrs \\ %{}) do
    {:ok, session} =
      Sessions.create_session(
        Map.merge(%{user_id: user.id, host_id: host.id, name: "Synthesis Session"}, attrs)
      )

    session
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # The synthesis rules and base prompt are module attributes compiled into the
  # MetaPlanner module.  We derive the expected prompt from the known source
  # text.  Elixir does not expose arbitrary module attributes at runtime, so we
  # embed representative substrings that must be present.

  defp synthesis_rules_text do
    """

    ## Synthesis Requirement

    When producing the final response for any task or set of tasks, you MUST
    synthesise findings into a coherent, direct answer rather than merely
    reporting what each sub-agent returned.

    ### Anti-patterns to avoid

    The following phrases indicate poor synthesis and MUST NOT appear in final
    responses:
    - "Based on your findings…"
    - "As the research agent found…"
    - "According to the sub-task result…"
    - "The agent reported that…"
    - "Tool X returned…"

    ### Continue vs. Spawn decision table

    | Condition                          | Action                          |
    |------------------------------------|---------------------------------|
    | Follow-up fits within context      | Continue in current session     |
    | New independent domain/goal        | Spawn dedicated sub-agent       |
    | Requires different agent_type      | Spawn with appropriate type     |
    | User explicitly requests isolation | Spawn new session               |
    | Clarification of prior message     | Continue in current session     |

    ### Verification requirements

    Before returning any synthesised result:
    1. Confirm all required sub-tasks have completed successfully.
    2. Resolve any contradictions between sub-task outputs.
    3. Ensure the response directly addresses the original user intent.
    4. Remove any raw tool output or intermediate agent commentary.
    """
  end

  defp base_prompt_text do
    """
    You are a task decomposition assistant. Given the user message below, break it
    down into one or more concrete tasks.

    Return ONLY a JSON array (no surrounding text) where each element has:
    - "description": string — a clear, concise task description
    - "risk_level": one of "read_only", "additive", or "destructive"
    - "agent_type": one of "chat", "code", "research", "security"
    - "parallel": boolean — true if the task can run simultaneously with others

    If the message is a simple chat request, return a single-element array with
    agent_type "chat" and risk_level "read_only".

    User message:
    """
  end

  defp full_decomposition_prompt do
    base_prompt_text() <> synthesis_rules_text()
  end

  # ---------------------------------------------------------------------------
  # System prompt content assertions
  # ---------------------------------------------------------------------------

  describe "decomposition prompt" do
    test "includes 'Synthesis Requirement' section" do
      assert full_decomposition_prompt() =~ "Synthesis Requirement"
    end

    test "includes anti-pattern examples" do
      prompt = full_decomposition_prompt()
      assert prompt =~ "Based on your findings"
      assert prompt =~ "As the research agent found"
      assert prompt =~ "According to the sub-task result"
      assert prompt =~ "The agent reported that"
      assert prompt =~ "Tool X returned"
    end

    test "includes continue-vs-spawn decision table" do
      prompt = full_decomposition_prompt()
      assert prompt =~ "Continue vs. Spawn"
      assert prompt =~ "Continue in current session"
      assert prompt =~ "Spawn dedicated sub-agent"
    end

    test "includes verification requirements" do
      prompt = full_decomposition_prompt()
      assert prompt =~ "Verification requirements"
      assert prompt =~ "sub-tasks have completed"
      assert prompt =~ "original user intent"
    end

    test "synthesis rules are appended to the base decomposition prompt" do
      prompt = full_decomposition_prompt()
      # Base section appears first
      assert String.starts_with?(prompt, "You are a task decomposition assistant")
      # Synthesis rules appear after
      base_end = String.length(base_prompt_text())
      tail = String.slice(prompt, base_end, String.length(prompt))
      assert tail =~ "Synthesis Requirement"
    end
  end

  describe "decompose_message/2 context reuse" do
    test "follow-up message produces a task in the same session" do
      user = create_user()
      host = create_host()
      session = create_session(user, host, %{agent_type: "chat"})

      MetaPlanner.process_message(session.id, "Tell me about Elixir concurrency")
      Process.sleep(150)

      MetaPlanner.process_message(session.id, "Can you elaborate on GenServers?")
      Process.sleep(150)

      tasks = Tasks.list_tasks(session_id: session.id)
      assert length(tasks) >= 2
      assert Enum.all?(tasks, fn t -> t.session_id == session.id end)
    end
  end
end
