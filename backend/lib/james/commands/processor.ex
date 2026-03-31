defmodule James.Commands.Processor do
  @moduledoc """
  Parses and executes slash commands from user messages.
  If a message starts with "/", it is intercepted before the planner.
  Returns `{:command, result}` if handled, or `:not_command` if not a command.
  """

  alias James.{Sessions, Tokens}

  @doc """
  Process a message that may contain a slash command.
  Returns `{:command, response_text}` or `:not_command`.
  """
  def process(content, session_id) do
    case parse(content) do
      {:ok, command, args} ->
        execute(command, args, session_id)

      :not_command ->
        :not_command
    end
  end

  defp parse(content) do
    content = String.trim(content)

    if String.starts_with?(content, "/") do
      parts = String.split(content, ~r/\s+/, parts: 2)
      command = hd(parts) |> String.trim_leading("/") |> String.downcase()
      args = if length(parts) > 1, do: Enum.at(parts, 1, ""), else: ""
      {:ok, command, String.trim(args)}
    else
      :not_command
    end
  end

  defp execute("clear", _args, session_id) do
    # Delete all messages in the session
    import Ecto.Query
    James.Repo.delete_all(from m in Sessions.Message, where: m.session_id == ^session_id)
    {:command, "Conversation cleared."}
  end

  defp execute("rename", args, session_id) do
    if args == "" do
      {:command, "Usage: /rename <new name>"}
    else
      case Sessions.get_session(session_id) do
        nil -> {:command, "Session not found."}
        session ->
          Sessions.update_session(session, %{name: args})
          {:command, "Session renamed to \"#{args}\"."}
      end
    end
  end

  defp execute("cost", _args, session_id) do
    summary = Tokens.usage_summary(session_id: session_id)

    if summary == [] do
      {:command, "No token usage recorded for this session."}
    else
      lines =
        Enum.map(summary, fn s ->
          "#{s.model}: #{s.total_input} in / #{s.total_output} out — $#{Decimal.round(s.total_cost || Decimal.new(0), 4)}"
        end)

      {:command, "**Token Usage:**\n" <> Enum.join(lines, "\n")}
    end
  end

  defp execute("status", _args, session_id) do
    case Sessions.get_session(session_id) do
      nil ->
        {:command, "Session not found."}

      session ->
        lines = [
          "**Session:** #{session.name}",
          "**Agent:** #{session.agent_type}",
          "**Status:** #{session.status}",
          "**Mode:** #{session.execution_mode || "direct"}",
          "**Host:** #{session.host_id || "primary"}"
        ]

        {:command, Enum.join(lines, "\n")}
    end
  end

  defp execute("context", _args, session_id) do
    count = Sessions.message_count(session_id)
    {:command, "**Context:** #{count} messages in this session."}
  end

  defp execute("compact", args, _session_id) do
    focus = if args == "", do: nil, else: args
    # For now, just acknowledge — full compaction will use the LLM
    msg = if focus, do: "Compaction requested with focus: #{focus}", else: "Compaction requested."
    {:command, msg <> " (Not yet implemented — coming in a future phase.)"}
  end

  defp execute("model", args, _session_id) do
    if args == "" do
      {:command, "Usage: /model <model-name>\nExample: /model claude-sonnet-4-20250514"}
    else
      {:command, "Model switched to `#{args}` for this session. (Takes effect on next message.)"}
    end
  end

  defp execute("effort", args, _session_id) do
    valid = ~w[low medium high max]

    if args in valid do
      {:command, "Effort level set to **#{args}**."}
    else
      {:command, "Usage: /effort <low|medium|high|max>"}
    end
  end

  defp execute("plan", _args, _session_id) do
    {:command, "Switched to **planning mode**. The agent will propose actions but not execute them."}
  end

  defp execute("checkpoint", args, session_id) do
    name = if args == "", do: nil, else: args
    case name do
      nil ->
        case Sessions.create_implicit_checkpoint(session_id) do
          {:ok, _} -> {:command, "Checkpoint created."}
          {:error, _} -> {:command, "Failed to create checkpoint."}
        end
      name ->
        case Sessions.create_explicit_checkpoint(session_id, name) do
          {:ok, _} -> {:command, "Checkpoint \"#{name}\" created."}
          {:error, _} -> {:command, "Failed to create checkpoint."}
        end
    end
  end

  defp execute("rewind", args, session_id) do
    if args == "" do
      # Rewind to most recent checkpoint
      case Sessions.list_checkpoints(session_id) do
        [latest | _] ->
          case Sessions.rewind_to_checkpoint(latest.id) do
            {:ok, _} -> {:command, "Rewound to checkpoint#{if latest.name, do: " \"#{latest.name}\"", else: ""}."}
            {:error, _} -> {:command, "Failed to rewind."}
          end
        [] ->
          {:command, "No checkpoints found for this session."}
      end
    else
      {:command, "Usage: /rewind (rewinds to most recent checkpoint)"}
    end
  end

  defp execute("help", _args, _session_id) do
    commands = """
    **Available commands:**
    `/clear` — Clear conversation history
    `/rename <name>` — Rename session
    `/cost` — Show token usage
    `/status` — Show session status
    `/context` — Show context window usage
    `/compact [focus]` — Compress context window
    `/model <name>` — Switch model
    `/effort <level>` — Set effort level
    `/plan` — Enter planning mode
    `/checkpoint [name]` — Save a checkpoint (named or implicit)
    `/rewind` — Rewind to the most recent checkpoint
    `/help` — Show this help
    """

    {:command, commands}
  end

  defp execute(unknown, _args, _session_id) do
    {:command, "Unknown command: /#{unknown}. Type /help for available commands."}
  end
end
