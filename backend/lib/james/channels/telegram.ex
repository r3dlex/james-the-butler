defmodule James.Channels.Telegram do
  @moduledoc """
  Telegram bot integration. Routes messages to sessions and sends responses back.
  Supports thread-to-session routing, voice transcription placeholder, and confirmed mode timeout.
  """

  import Ecto.Query
  alias James.{Repo, Sessions, Planner.MetaPlanner}
  alias James.Channels.TelegramThread
  require Logger

  @confirmed_timeout_seconds 600

  def handle_message(telegram_thread_id, text, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    case resolve_session(telegram_thread_id) do
      {:ok, session_id} ->
        {:ok, message} =
          Sessions.create_message(%{session_id: session_id, role: "user", content: text})

        MetaPlanner.process_message(session_id, message)
        {:ok, session_id}

      :not_found ->
        if user_id do
          case create_session_for_thread(telegram_thread_id, user_id) do
            {:ok, session} ->
              {:ok, message} =
                Sessions.create_message(%{session_id: session.id, role: "user", content: text})

              MetaPlanner.process_message(session.id, message)
              {:ok, session.id}

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, :no_user}
        end
    end
  end

  def handle_voice(telegram_thread_id, _audio_data, opts) do
    handle_message(telegram_thread_id, "[Voice message — transcription not yet configured]", opts)
  end

  def handle_command(command, _args, opts) do
    user_id = Keyword.get(opts, :user_id)

    case command do
      "/sessions" ->
        sessions = Sessions.list_sessions(user_id, limit: 5)
        lines = Enum.map(sessions, fn s -> "• #{s.name} (#{String.slice(s.id, 0, 8)}...)" end)
        {:ok, "Recent sessions:\n" <> Enum.join(lines, "\n")}

      _ ->
        {:ok, "Unknown command. Available: /sessions"}
    end
  end

  def confirmed_timeout, do: @confirmed_timeout_seconds

  defp resolve_session(telegram_thread_id) do
    case Repo.one(from(t in TelegramThread, where: t.telegram_thread_id == ^telegram_thread_id)) do
      %{session_id: sid} -> {:ok, sid}
      nil -> :not_found
    end
  end

  defp create_session_for_thread(telegram_thread_id, user_id) do
    case Sessions.create_session(%{name: "Telegram Thread", user_id: user_id, agent_type: "chat"}) do
      {:ok, session} ->
        %TelegramThread{}
        |> TelegramThread.changeset(%{
          telegram_thread_id: telegram_thread_id,
          session_id: session.id,
          user_id: user_id
        })
        |> Repo.insert()

        {:ok, session}

      error ->
        error
    end
  end
end
