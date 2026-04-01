defmodule James.Compaction do
  @moduledoc """
  Manages session compaction to prevent context window overflow.

  When a session's token usage approaches the context window limit (default 80%
  threshold), compaction summarises older messages into a Checkpoint and removes
  them from the messages table. The most recent `keep_last` messages are
  preserved so the agent retains immediate context.

  A forked session can be created from a compacted checkpoint, injecting the
  summary as a system message so the new session starts with full context.
  """

  import Ecto.Query

  alias James.Repo
  alias James.Sessions
  alias James.Sessions.{Checkpoint, Message}

  @default_context_limit 200_000
  @compaction_threshold 0.8
  @default_keep_last 4

  @doc """
  Returns the ratio of total message tokens for `session_id` to `context_limit`.
  Result is clamped to [0.0, 1.0].
  """
  @spec token_ratio(binary(), keyword()) :: float()
  def token_ratio(session_id, opts \\ []) do
    context_limit = Keyword.get(opts, :context_limit, @default_context_limit)

    total =
      Repo.one(
        from m in Message,
          where: m.session_id == ^session_id,
          select: coalesce(sum(m.token_count), 0)
      ) || 0

    if total == 0 do
      0.0
    else
      min(total / context_limit, 1.0)
    end
  end

  @doc """
  Returns `true` when the session's token ratio meets or exceeds the 0.8
  compaction threshold.
  """
  @spec needs_compaction?(binary(), keyword()) :: boolean()
  def needs_compaction?(session_id, opts \\ []) do
    token_ratio(session_id, opts) >= @compaction_threshold
  end

  @doc """
  Compacts `session_id` by:
  1. Selecting the oldest messages (all except the last `keep_last`)
  2. Storing them in a Checkpoint with the provided `summary`
  3. Deleting the compacted messages from the messages table

  Returns `{:ok, checkpoint}` or `{:error, changeset}`.
  """
  @spec compact!(binary(), String.t(), keyword()) ::
          {:ok, Checkpoint.t()} | {:error, Ecto.Changeset.t()}
  def compact!(session_id, summary, opts \\ []) do
    keep_last = Keyword.get(opts, :keep_last, @default_keep_last)

    all_messages =
      Repo.all(
        from m in Message,
          where: m.session_id == ^session_id,
          order_by: [asc: m.inserted_at]
      )

    total = length(all_messages)
    compacted_count = max(total - keep_last, 0)
    {to_compact, _to_keep} = Enum.split(all_messages, compacted_count)

    snapshot_messages =
      Enum.map(to_compact, fn m ->
        %{"role" => m.role, "content" => m.content, "token_count" => m.token_count}
      end)

    result =
      Repo.transaction(fn ->
        # Delete compacted messages
        if to_compact != [] do
          ids = Enum.map(to_compact, & &1.id)

          Repo.delete_all(
            from m in Message,
              where: m.id in ^ids
          )
        end

        # Create checkpoint
        %Checkpoint{}
        |> Checkpoint.changeset(%{
          session_id: session_id,
          type: "implicit",
          name: "compaction:#{DateTime.utc_now() |> DateTime.to_iso8601()}",
          conversation_snapshot: %{"messages" => snapshot_messages},
          metadata: %{
            "summary" => summary,
            "message_count" => compacted_count,
            "compaction" => true
          }
        })
        |> Repo.insert!()
      end)

    case result do
      {:ok, checkpoint} -> {:ok, checkpoint}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a text summary for a list of messages.

  In `:mock` mode (used in tests), returns a deterministic mock summary.
  In normal mode, delegates to the configured LLM provider.
  """
  @spec summarize_messages(list(map()), keyword()) :: String.t()
  def summarize_messages(messages, opts \\ []) do
    case Keyword.get(opts, :mode, :llm) do
      :mock ->
        roles = Enum.map_join(messages, ", ", & &1.role)
        "[mock summary: #{length(messages)} messages (#{roles})]"

      :llm ->
        prompt = build_summary_prompt(messages)
        provider = James.LLMProvider.configured()

        case provider.send_message([%{role: "user", content: prompt}]) do
          {:ok, %{content: text}} -> text
          {:error, _} -> "[summary unavailable]"
        end
    end
  end

  @doc """
  Creates a new session forked from `session_id`, using `checkpoint_id` as the
  starting context. The forked session begins with a system message containing
  the checkpoint summary.
  """
  @spec fork_session(binary(), binary()) ::
          {:ok, Sessions.Session.t()} | {:error, any()}
  def fork_session(session_id, checkpoint_id) do
    with %Sessions.Session{} = original <- Sessions.get_session(session_id),
         %Checkpoint{} = checkpoint <- Repo.get(Checkpoint, checkpoint_id),
         summary <- checkpoint.metadata["summary"] || "",
         {:ok, forked} <-
           Sessions.create_session(%{
             user_id: original.user_id,
             host_id: original.host_id,
             project_id: original.project_id,
             agent_type: original.agent_type,
             execution_mode: original.execution_mode,
             name: "fork:#{session_id}"
           }) do
      # Inject summary as a system message
      Sessions.create_message(%{
        session_id: forked.id,
        role: "system",
        content: "Context from previous session:\n\n#{summary}"
      })

      {:ok, forked}
    else
      nil -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  # --- Private ---

  defp build_summary_prompt(messages) do
    lines =
      Enum.map_join(messages, "\n", fn %{role: role, content: content} ->
        "#{String.upcase(role)}: #{content}"
      end)

    """
    Summarize the following conversation concisely, capturing the key decisions,
    context, and outcomes. The summary will be used to resume the conversation.

    #{lines}
    """
  end
end
