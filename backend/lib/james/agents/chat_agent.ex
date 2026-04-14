defmodule James.Agents.ChatAgent do
  @moduledoc """
  GenServer that handles a single chat agent task.
  Calls the Anthropic API with streaming, broadcasts chunks to the session channel,
  saves the completed message, and records token usage.
  """

  use GenServer, restart: :temporary

  alias James.{Embeddings, LLMProvider, Memories, Personality, Sessions, Tasks, Tokens}
  alias James.Hooks.Dispatcher
  alias James.Providers.Registry
  alias James.Workers.MemoryExtractionWorker

  defstruct [
    :session_id,
    :task_id,
    :messages,
    :system_prompt,
    :model,
    :provider,
    :provider_opts,
    :first_user_message,
    :memory_context
  ]

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
    explicit_provider = Keyword.get(opts, :provider)
    session = Sessions.get_session(session_id)
    system_prompt = Keyword.get(opts, :system_prompt) || resolve_system_prompt(session)

    # Resolve provider module and credentials from DB config.
    # An explicit :provider opt overrides the module but the DB credentials
    # (api_key, base_url) are still injected as opts so callers don't need
    # to manage keys directly.
    {resolved_provider, _resolved_model, resolved_opts} =
      Registry.resolve_provider(session || %{})

    provider = explicit_provider || resolved_provider
    provider_opts = resolved_opts

    # Load conversation history
    messages =
      Sessions.list_messages(session_id)
      |> Enum.map(fn msg ->
        %{role: normalize_role(msg.role), content: msg.content}
      end)

    # Fetch memory context using the FIRST user message (for cold-start retrieval)
    first_user_msg = messages |> Enum.filter(&(&1.role == "user")) |> List.first()

    memory_context =
      if first_user_msg do
        user_id = session.user_id

        case Memories.get_recent_memories(user_id, first_user_msg.content,
               memory_types: ["user_preference", "session_summary"],
               limit: 5
             ) do
          {:ok, results} -> results
          _ -> []
        end
      else
        []
      end

    # Inject working directories into system prompt
    working_dirs_context = build_working_dirs_context(session)

    # Inject relevant memories into system prompt
    previous_session_context = build_previous_session_context(session)

    full_system =
      system_prompt
      |> prepend_memory_section(memory_context)
      |> append_section(working_dirs_context)
      |> append_section(
        if previous_session_context != "",
          do: "## Relevant context from previous sessions:\n" <> previous_session_context,
          else: ""
      )
      |> append_section(arch_rules())

    state = %__MODULE__{
      session_id: session_id,
      task_id: task_id,
      messages: messages,
      system_prompt: full_system,
      model: model,
      provider: provider,
      provider_opts: provider_opts,
      first_user_message: first_user_msg,
      memory_context: memory_context
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

    opts =
      (state.provider_opts || [])
      |> Keyword.put(:system, state.system_prompt)
      |> Keyword.put(:on_chunk, fn text ->
        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:assistant_chunk, text}
        )
      end)

    opts = if state.model, do: Keyword.put(opts, :model, state.model), else: opts

    llm_provider = state.provider || LLMProvider.configured()

    case llm_provider.stream_message(state.messages, opts) do
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
        Dispatcher.fire(:post_tool_use_failure, %{
          session_id: session_id,
          tool_name: "llm",
          error_message: inspect(reason)
        })

        error_text = format_llm_error(reason)

        # Save as a DB message so it persists and closes streaming on the frontend
        {:ok, err_msg} =
          Sessions.create_message(%{
            session_id: session_id,
            role: "assistant",
            content: error_text
          })

        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:assistant_message, err_msg}
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
    case Tasks.get_task(task_id) do
      nil ->
        :ok

      task ->
        {:ok, updated} = Tasks.update_task_status(task, status)

        Phoenix.PubSub.broadcast(
          James.PubSub,
          "session:#{session_id}",
          {:task_updated, updated}
        )
    end
  end

  defp format_llm_error(reason) when is_binary(reason) do
    if String.ends_with?(reason, "_API_KEY not configured") or
         reason == "ANTHROPIC_API_KEY not configured" do
      "No LLM provider is configured. Please add an API key in **Settings → Models**."
    else
      "⚠️ #{reason}"
    end
  end

  defp format_llm_error(reason), do: "⚠️ #{inspect(reason)}"

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

  defp fetch_memory_context(user_id, content) do
    {:ok, embedding} = Embeddings.generate(content)
    format_memories(Memories.search_similar(user_id, embedding, 5))
  end

  defp build_previous_session_context(nil), do: ""

  defp build_previous_session_context(session) do
    messages = Sessions.list_messages(session.id)
    last_user_msg = messages |> Enum.filter(&(&1.role == "user")) |> List.last()

    if last_user_msg do
      fetch_memory_context(session.user_id, last_user_msg.content)
    else
      ""
    end
  end

  defp format_memories([]), do: ""

  defp format_memories(memories) do
    Enum.map_join(memories, "\n", fn m -> "- #{m.content}" end)
  end

  defp prepend_memory_section(prompt, memory_context) do
    if length(memory_context) > 0 do
      memory_section = """
      ## Project Memory
      #{Enum.map_join(memory_context, "\n", fn m -> "- #{m.content}" end)}
      """

      append_section(prompt, memory_section)
    else
      prompt
    end
  end

  defp arch_rules do
    """
    ## Architectural Rules
    - All business logic goes in `lib/james/` domain modules, NOT in controllers or channels
    - Database queries go through `Repo` or domain modules, never raw Ecto queries in controllers
    - Channels handle only message routing and PubSub; no business logic
    - Workers handle async side effects; no HTTP calls or DB writes directly from GenServers
    - New modules require corresponding unit tests in `test/james/`
    """
  end

  defp enqueue_memory_extraction(session_id) do
    case Sessions.get_session(session_id) do
      %{user_id: user_id} ->
        job =
          %{session_id: session_id, user_id: user_id}
          |> MemoryExtractionWorker.new()

        try do
          Oban.insert(job)
        rescue
          _ -> :ok
        end

      _ ->
        :ok
    end
  end

  defp build_working_dirs_context(nil), do: "No specific working directory is configured."

  defp build_working_dirs_context(%{working_directories: [_ | _] = dirs}) do
    "Working directories available: " <> Enum.join(dirs, ", ")
  end

  defp build_working_dirs_context(_session), do: "No specific working directory is configured."

  defp append_section(prompt, ""), do: prompt
  defp append_section(prompt, section), do: prompt <> "\n\n" <> section

  defp resolve_system_prompt(nil), do: default_system_prompt()
  defp resolve_system_prompt(session), do: Personality.resolve_system_prompt(session)

  defp default_system_prompt do
    """
    You are James the Butler, an AI assistant. You are helpful, precise, and direct.
    Respond clearly and concisely. When appropriate, use markdown formatting.
    """
  end
end
