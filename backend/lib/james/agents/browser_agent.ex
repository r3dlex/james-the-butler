defmodule James.Agents.BrowserAgent do
  @moduledoc """
  Agent for browser automation via Chrome DevTools Protocol (CDP).
  Manages Chrome instances, navigates pages, and interacts with web content.
  """

  use GenServer, restart: :temporary

  alias James.{Sessions, Tokens}
  alias James.Providers.Anthropic

  defstruct [:session_id, :task_id, :messages, :system_prompt, :model]

  @tools [
    %{
      name: "navigate",
      description: "Navigate the browser to a URL.",
      input_schema: %{
        type: "object",
        properties: %{url: %{type: "string", description: "URL to navigate to"}},
        required: ["url"]
      }
    },
    %{
      name: "click_element",
      description: "Click an element identified by CSS selector.",
      input_schema: %{
        type: "object",
        properties: %{selector: %{type: "string", description: "CSS selector"}},
        required: ["selector"]
      }
    },
    %{
      name: "fill_form",
      description: "Fill a form field with text.",
      input_schema: %{
        type: "object",
        properties: %{
          selector: %{type: "string", description: "CSS selector of the input"},
          value: %{type: "string", description: "Value to fill"}
        },
        required: ["selector", "value"]
      }
    },
    %{
      name: "get_page_content",
      description: "Get the text content of the current page.",
      input_schema: %{type: "object", properties: %{}, required: []}
    },
    %{
      name: "run_javascript",
      description: "Execute JavaScript in the browser context.",
      input_schema: %{
        type: "object",
        properties: %{script: %{type: "string", description: "JavaScript code to execute"}},
        required: ["script"]
      }
    },
    %{
      name: "screenshot_page",
      description: "Take a screenshot of the current page.",
      input_schema: %{type: "object", properties: %{}, required: []}
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
      system_prompt: browser_system_prompt(),
      model: model
    }

    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    broadcast_task_status(state.session_id, state.task_id, "running")

    case James.Browser.CdpManager.ensure_chrome() do
      :ok ->
        run_loop(state, 0)

      {:error, reason} ->
        broadcast_chunk(state.session_id, "Chrome not available: #{reason}")
        broadcast_task_status(state.session_id, state.task_id, "failed")
    end

    {:stop, :normal, state}
  end

  defp run_loop(state, iteration) when iteration >= 30 do
    broadcast_chunk(state.session_id, "\n\n[Browser agent reached maximum iterations]")
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
        {:ok, _msg} = Sessions.create_message(%{
          session_id: state.session_id, role: "assistant", content: content,
          model: state.model || "claude-sonnet-4-20250514"
        })
        record_tokens(state, usage)

        if stop_reason == "tool_use" do
          tool_results = execute_tool_calls(content)
          updated = state.messages ++ [
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
      result = James.Browser.CdpManager.execute(tc["name"], tc["input"] || %{})
      %{type: "tool_result", tool_use_id: tc["id"], content: result}
    end)
  end

  defp broadcast_chunk(sid, text), do: Phoenix.PubSub.broadcast(James.PubSub, "session:#{sid}", {:assistant_chunk, text})
  defp broadcast_task_status(_sid, nil, _status), do: :ok
  defp broadcast_task_status(sid, tid, status) do
    case James.Tasks.get_task(tid) do
      nil -> :ok
      task ->
        {:ok, updated} = James.Tasks.update_task_status(task, status)
        Phoenix.PubSub.broadcast(James.PubSub, "session:#{sid}", {:task_updated, updated})
    end
  end

  defp record_tokens(state, usage) do
    input = Map.get(usage, :input_tokens, 0)
    output = Map.get(usage, :output_tokens, 0)
    if input > 0 or output > 0 do
      Tokens.record_usage(%{
        session_id: state.session_id, task_id: state.task_id,
        model: state.model || "claude-sonnet-4-20250514",
        input_tokens: input, output_tokens: output,
        cost_usd: Decimal.add(
          Decimal.div(Decimal.new(input * 3), Decimal.new(1_000_000)),
          Decimal.div(Decimal.new(output * 15), Decimal.new(1_000_000))
        )
      })
    end
  end

  defp normalize_role("user"), do: "user"
  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role(_), do: "user"

  defp browser_system_prompt do
    """
    You are James the Butler, a browser automation agent. You control a Chrome browser
    via CDP to navigate web pages, interact with elements, and extract information.

    Available tools:
    - navigate: Go to a URL
    - click_element: Click a CSS selector
    - fill_form: Fill an input field
    - get_page_content: Read the page text
    - run_javascript: Execute JS in the browser
    - screenshot_page: Take a page screenshot

    Always start by navigating to the target URL and getting page content to understand
    the current state before interacting.
    """
  end
end
