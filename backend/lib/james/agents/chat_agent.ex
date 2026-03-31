defmodule James.Agents.ChatAgent do
  @moduledoc """
  GenServer that handles a single chat agent task.
  Calls the Anthropic API with streaming, broadcasts chunks to the session channel,
  saves the completed message, and records token usage.
  """

  use GenServer, restart: :temporary

  alias James.{Sessions, Tokens, Memories, Embeddings}
  alias James.Providers.Anthropic

  defstruct [:session_id, :task_id, :messages, :system_prompt, :model]

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    task_id = Keyword.get(opts, :task_id)
    model = Keyword.get(opts, :model)
    system_prompt = Keyword.get(opts, :system_prompt, default_system_prompt())

    # Load conversation history
    messages =
      Sessions.list_messages(session_id)
      |> Enum.map(fn msg ->
        %{role: normalize_role(msg.role), content: msg.content}
      end)

    # Inject relevant memories into system prompt
    session = Sessions.get_session(session_id)
    memory_context = build_memory_context(session)

    full_system =
      if memory_context != "" do
        system_prompt <> "\n\n## Relevant context from previous sessions:\n" <> memory_context
      else
        system_prompt
      end

    state = %__MODULE__{
      session_id: session_id,
      task_id: task_id,
      messages: messages,
      system_prompt: full_system,
      model: model
    }

    # Start processing immediately
    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    session_id = state.session_id

    # Notify task started
    broadcast_task_status(session_id, state.task_id, "running")

    opts = [
      system: state.system_prompt,
      on_chunk: fn text ->
        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:assistant_chunk, text}
        )
      end
    ]

    opts = if state.model, do: Keyword.put(opts, :model, state.model), else: opts

    case Anthropic.stream_message(state.messages, opts) do
      {:ok, %{content: content, usage: usage}} ->
        # Save assistant message
        {:ok, message} =
          Sessions.create_message(%{
            session_id: session_id,
            role: "assistant",
            content: content,
            token_count: Map.get(usage, :output_tokens, 0),
            model: state.model || "claude-sonnet-4-20250514"
          })

        # Broadcast the completed message
        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:assistant_message, message}
        )

        # Record token usage
        record_tokens(state, usage)

        # Enqueue memory extraction
        enqueue_memory_extraction(session_id)

        # Mark task completed
        broadcast_task_status(session_id, state.task_id, "completed")

      {:error, reason} ->
        # Broadcast error as a system message
        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:assistant_chunk, "\n\n[Error: #{inspect(reason)}]"}
        )

        broadcast_task_status(session_id, state.task_id, "failed")
    end

    {:stop, :normal, state}
  end

  # --- Private ---

  defp normalize_role("user"), do: "user"
  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role(_), do: "user"

  defp broadcast_task_status(_session_id, nil, _status), do: :ok

  defp broadcast_task_status(session_id, task_id, status) do
    case James.Tasks.get_task(task_id) do
      nil -> :ok
      task ->
        {:ok, updated} = James.Tasks.update_task_status(task, status)

        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:task_updated, updated}
        )
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
        cost_usd: estimate_cost(input, output)
      })
    end
  end

  defp estimate_cost(input, output) do
    # Sonnet pricing: $3/M input, $15/M output
    Decimal.add(
      Decimal.div(Decimal.new(input * 3), Decimal.new(1_000_000)),
      Decimal.div(Decimal.new(output * 15), Decimal.new(1_000_000))
    )
  end

  defp build_memory_context(nil), do: ""

  defp build_memory_context(session) do
    # Get the last user message to use as query for memory retrieval
    messages = Sessions.list_messages(session.id)
    last_user_msg = messages |> Enum.filter(&(&1.role == "user")) |> List.last()

    if last_user_msg do
      case Embeddings.generate(last_user_msg.content) do
        {:ok, embedding} ->
          memories = Memories.search_similar(session.user_id, embedding, 5)

          if memories != [] do
            memories
            |> Enum.map(& &1.content)
            |> Enum.map_join("\n", fn c -> "- #{c}" end)
          else
            ""
          end

        {:error, _} ->
          ""
      end
    else
      ""
    end
  end

  defp enqueue_memory_extraction(session_id) do
    case James.Sessions.get_session(session_id) do
      %{user_id: user_id} ->
        %{session_id: session_id, user_id: user_id}
        |> James.Workers.MemoryExtractionWorker.new()
        |> Oban.insert()

      _ ->
        :ok
    end
  end

  defp default_system_prompt do
    """
    You are James the Butler, an AI assistant. You are helpful, precise, and direct.
    Respond clearly and concisely. When appropriate, use markdown formatting.
    """
  end
end
