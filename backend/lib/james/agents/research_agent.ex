defmodule James.Agents.ResearchAgent do
  @moduledoc """
  Agent specialized for web research, content retrieval, and structured report generation.
  Uses tool_use for web_search, fetch_url, and create_report tools.
  """

  use GenServer, restart: :temporary

  alias James.{Sessions, Tokens}
  alias James.Providers.Anthropic

  defstruct [:session_id, :task_id, :messages, :system_prompt, :model]

  @tools [
    %{
      name: "web_search",
      description: "Search the web for information on a topic.",
      input_schema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Search query"}
        },
        required: ["query"]
      }
    },
    %{
      name: "fetch_url",
      description: "Fetch and extract text content from a URL.",
      input_schema: %{
        type: "object",
        properties: %{
          url: %{type: "string", description: "URL to fetch"}
        },
        required: ["url"]
      }
    },
    %{
      name: "create_report",
      description: "Save a structured research report as a markdown document.",
      input_schema: %{
        type: "object",
        properties: %{
          title: %{type: "string", description: "Report title"},
          content: %{type: "string", description: "Report content in markdown"}
        },
        required: ["title", "content"]
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
      system_prompt: research_system_prompt(),
      model: model
    }

    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    broadcast_task_status(state.session_id, state.task_id, "running")
    run_loop(state, 0)
    {:stop, :normal, state}
  end

  defp run_loop(state, iteration) when iteration >= 15 do
    broadcast_chunk(state.session_id, "\n\n[Research agent reached maximum iterations]")
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
        {:ok, message} = Sessions.create_message(%{
          session_id: state.session_id,
          role: "assistant",
          content: content,
          token_count: Map.get(usage, :output_tokens, 0),
          model: state.model || "claude-sonnet-4-20250514"
        })

        Phoenix.PubSub.broadcast(James.PubSub, "session:#{state.session_id}", {:assistant_message, message})
        record_tokens(state, usage)

        if stop_reason == "tool_use" do
          tool_results = execute_tool_calls(content, state)
          updated_messages = state.messages ++ [
            %{role: "assistant", content: content},
            %{role: "user", content: tool_results}
          ]
          run_loop(%{state | messages: updated_messages}, iteration + 1)
        else
          broadcast_task_status(state.session_id, state.task_id, "completed")
        end

      {:error, reason} ->
        broadcast_chunk(state.session_id, "\n\n[Error: #{inspect(reason)}]")
        broadcast_task_status(state.session_id, state.task_id, "failed")
    end
  end

  defp execute_tool_calls(content, _state) when is_binary(content), do: []
  defp execute_tool_calls(content, state) when is_list(content) do
    content
    |> Enum.filter(fn b -> is_map(b) and Map.get(b, "type") == "tool_use" end)
    |> Enum.map(fn tc ->
      result = execute_tool(tc["name"], tc["input"] || %{}, state)
      %{type: "tool_result", tool_use_id: tc["id"], content: result}
    end)
  end

  defp execute_tool("web_search", %{"query" => query}, _state) do
    # Web search integration placeholder — would use a search API
    "Web search results for: #{query}\n[Search integration not yet configured. Please provide a search API key in settings.]"
  end

  defp execute_tool("fetch_url", %{"url" => url}, _state) do
    case Req.get(url, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        # Basic HTML stripping for text extraction
        body
        |> String.replace(~r/<script[^>]*>.*?<\/script>/s, "")
        |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
        |> String.replace(~r/<[^>]+>/, " ")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
        |> String.slice(0, 10_000)

      {:ok, %{status: status}} ->
        "Error fetching URL: HTTP #{status}"

      {:error, reason} ->
        "Error fetching URL: #{inspect(reason)}"
    end
  end

  defp execute_tool("create_report", %{"title" => title, "content" => content}, state) do
    # Save as an artifact message
    Sessions.create_message(%{
      session_id: state.session_id,
      role: "system",
      content: "## #{title}\n\n#{content}"
    })
    "Report '#{title}' saved."
  end

  defp execute_tool(name, _input, _state), do: "Unknown tool: #{name}"

  defp broadcast_chunk(session_id, text) do
    Phoenix.PubSub.broadcast(James.PubSub, "session:#{session_id}", {:assistant_chunk, text})
  end

  defp broadcast_task_status(_sid, nil, _status), do: :ok
  defp broadcast_task_status(sid, task_id, status) do
    case James.Tasks.get_task(task_id) do
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
        session_id: state.session_id,
        task_id: state.task_id,
        model: state.model || "claude-sonnet-4-20250514",
        input_tokens: input,
        output_tokens: output,
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

  defp research_system_prompt do
    """
    You are James the Butler, a research-focused AI agent. Your job is to find, analyze, and synthesize information.

    Available tools:
    - web_search: Search the web for information
    - fetch_url: Retrieve content from a URL
    - create_report: Save a structured research report

    Guidelines:
    - Search multiple sources to verify information
    - Cite your sources
    - Create structured reports with clear sections
    - Flag uncertainties and conflicting information
    - Present findings clearly with markdown formatting
    """
  end
end
