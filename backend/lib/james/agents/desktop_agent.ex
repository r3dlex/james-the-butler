defmodule James.Agents.DesktopAgent do
  @moduledoc """
  Agent for desktop automation via the native daemon.
  Communicates with a local daemon process for screen capture and input simulation.
  Currently a scaffold — full implementation requires the platform daemon.
  """

  use GenServer, restart: :temporary

  alias James.Desktop.Daemon
  alias James.Providers.Anthropic
  alias James.{Sessions, Tasks, Tokens}

  defstruct [:session_id, :task_id, :messages, :system_prompt, :model]

  @tools [
    %{
      name: "screenshot",
      description: "Take a screenshot of the current screen.",
      input_schema: %{type: "object", properties: %{}, required: []}
    },
    %{
      name: "click",
      description: "Click at screen coordinates.",
      input_schema: %{
        type: "object",
        properties: %{
          x: %{type: "integer", description: "X coordinate"},
          y: %{type: "integer", description: "Y coordinate"}
        },
        required: ["x", "y"]
      }
    },
    %{
      name: "type_text",
      description: "Type text at the current cursor position.",
      input_schema: %{
        type: "object",
        properties: %{text: %{type: "string", description: "Text to type"}},
        required: ["text"]
      }
    },
    %{
      name: "key_press",
      description: "Press a keyboard key or combination.",
      input_schema: %{
        type: "object",
        properties: %{key: %{type: "string", description: "Key name (e.g. 'enter', 'cmd+c')"}},
        required: ["key"]
      }
    }
  ]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    task_id = Keyword.get(opts, :task_id)
    model = Keyword.get(opts, :model)

    messages =
      Sessions.list_messages(session_id)
      |> Enum.map(fn msg -> %{role: normalize_role(msg.role), content: msg.content} end)

    state = %__MODULE__{
      session_id: session_id,
      task_id: task_id,
      messages: messages,
      system_prompt: desktop_system_prompt(),
      model: model
    }

    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    broadcast_task_status(state.session_id, state.task_id, "running")

    # Check if daemon is available
    case Daemon.status() do
      :connected ->
        run_loop(state, 0)

      :disconnected ->
        broadcast_chunk(
          state.session_id,
          "Desktop daemon is not running. Please start the daemon and try again."
        )

        broadcast_task_status(state.session_id, state.task_id, "failed")
    end

    {:stop, :normal, state}
  end

  defp run_loop(state, iteration) when iteration >= 50 do
    broadcast_chunk(state.session_id, "\n\n[Desktop agent reached maximum iterations]")
    broadcast_task_status(state.session_id, state.task_id, "completed")
  end

  defp run_loop(state, iteration) do
    opts = [
      system: state.system_prompt,
      tools: @tools,
      on_chunk: fn text -> broadcast_chunk(state.session_id, text) end
    ]

    opts = if state.model, do: Keyword.put(opts, :model, state.model), else: opts

    case Anthropic.stream_message(state.messages, opts) do
      {:ok, %{content: content, usage: usage, stop_reason: stop_reason}} ->
        {:ok, _msg} =
          Sessions.create_message(%{
            session_id: state.session_id,
            role: "assistant",
            content: content,
            model: state.model || "claude-sonnet-4-20250514"
          })

        record_tokens(state, usage)

        if stop_reason == "tool_use" do
          tool_results = execute_tool_calls(content)

          updated =
            state.messages ++
              [
                %{role: "assistant", content: content},
                %{role: "user", content: tool_results}
              ]

          run_loop(%{state | messages: updated}, iteration + 1)
        else
          broadcast_task_status(state.session_id, state.task_id, "completed")
        end

      {:error, reason} ->
        broadcast_chunk(state.session_id, "\n\n[Error: #{inspect(reason)}]")
        broadcast_task_status(state.session_id, state.task_id, "failed")
    end
  end

  defp execute_tool_calls(content) when is_binary(content), do: []

  defp execute_tool_calls(content) when is_list(content) do
    content
    |> Enum.filter(fn b -> is_map(b) and Map.get(b, "type") == "tool_use" end)
    |> Enum.map(fn tc ->
      result = Daemon.execute(tc["name"], tc["input"] || %{})
      %{type: "tool_result", tool_use_id: tc["id"], content: result}
    end)
  end

  defp broadcast_chunk(sid, text),
    do: Phoenix.PubSub.broadcast(James.PubSub, "session:#{sid}", {:assistant_chunk, text})

  defp broadcast_task_status(_sid, nil, _status), do: :ok

  defp broadcast_task_status(sid, tid, status) do
    case Tasks.get_task(tid) do
      nil ->
        :ok

      task ->
        {:ok, updated} = Tasks.update_task_status(task, status)
        Phoenix.PubSub.broadcast(James.PubSub, "session:#{sid}", {:task_updated, updated})
    end
  end

  defp record_tokens(state, usage) do
    input = Map.get(usage, :input_tokens, 0)
    output = Map.get(usage, :output_tokens, 0)

    if input > 0 or output > 0 do
      Tokens.record_usage(%{
        session_id: state.session_id,
        task_id: state.task_id,
        model: state.model || "claude-sonnet-4-20250514",
        input_tokens: input,
        output_tokens: output,
        cost_usd:
          Decimal.add(
            Decimal.div(Decimal.new(input * 3), Decimal.new(1_000_000)),
            Decimal.div(Decimal.new(output * 15), Decimal.new(1_000_000))
          )
      })
    end
  end

  defp normalize_role("user"), do: "user"
  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role(_), do: "user"

  defp desktop_system_prompt do
    """
    You are James the Butler, a desktop automation agent. You control the user's desktop
    through screenshots and input actions. Take a screenshot first to understand the current
    screen state, then use click, type_text, and key_press to interact with applications.
    """
  end
end
