defmodule JamesWeb.SessionController do
  use Phoenix.Controller, formats: [:json]

  alias James.Commands.Processor
  alias James.Hosts
  alias James.Planner.MetaPlanner
  alias James.Sessions

  # GET /api/sessions
  def index(conn, params) do
    user = conn.assigns.current_user

    opts = [
      limit: String.to_integer(Map.get(params, "limit", "50")),
      cursor: Map.get(params, "cursor")
    ]

    sessions = Sessions.list_sessions(user.id, opts)
    conn |> json(%{sessions: Enum.map(sessions, &session_json/1)})
  end

  # POST /api/sessions
  def create(conn, params) do
    user = conn.assigns.current_user
    host = Hosts.get_primary_host()

    attrs = %{
      user_id: user.id,
      host_id: host && host.id,
      name: Map.get(params, "name"),
      project_id: Map.get(params, "project_id"),
      agent_type: Map.get(params, "agent_type", "chat"),
      personality_id: Map.get(params, "personality_id"),
      execution_mode: Map.get(params, "execution_mode")
    }

    case Sessions.create_session(attrs) do
      {:ok, session} ->
        conn |> put_status(:created) |> json(%{session: session_json(session)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  # GET /api/sessions/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Sessions.get_session(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      session when session.user_id != user.id ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      session ->
        count = Sessions.message_count(session.id)
        conn |> json(%{session: session_json(session, %{message_count: count})})
    end
  end

  # PUT /api/sessions/:id
  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with session when not is_nil(session) <- Sessions.get_session(id),
         true <- session.user_id == user.id,
         {:ok, updated} <-
           Sessions.update_session(
             session,
             Map.take(params, ["name", "execution_mode", "personality_id"])
           ) do
      conn |> json(%{session: session_json(updated)})
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  # DELETE /api/sessions/:id
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with session when not is_nil(session) <- Sessions.get_session(id),
         true <- session.user_id == user.id,
         {:ok, _} <- Sessions.archive_session(session) do
      conn |> json(%{ok: true})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
    end
  end

  # POST /api/sessions/:id/messages
  def send_message(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    content = Map.get(params, "content", "")

    with session when not is_nil(session) <- Sessions.get_session(id),
         true <- session.user_id == user.id,
         {:ok, message} <-
           Sessions.create_message(%{session_id: id, role: "user", content: content}),
         {:ok, _} <- Sessions.touch_session(session) do
      # Broadcast the user message over PubSub so the channel picks it up.
      Phoenix.PubSub.broadcast(James.PubSub, "session:#{id}", {:user_message, message})

      # Check for slash commands before dispatching to the planner
      case Processor.process(content, id) do
        {:command, response_text} ->
          # Save the command response as an assistant message
          {:ok, cmd_msg} =
            Sessions.create_message(%{
              session_id: id,
              role: "assistant",
              content: response_text
            })

          Phoenix.PubSub.broadcast(
            James.PubSub,
            "session:#{id}",
            {:assistant_message, cmd_msg}
          )

          conn
          |> put_status(:ok)
          |> json(%{message: message_json(message), command_response: message_json(cmd_msg)})

        :not_command ->
          # Dispatch to the meta-planner for task decomposition and agent execution
          MetaPlanner.process_message(id, message)
          conn |> put_status(:accepted) |> json(%{message: message_json(message)})
      end
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  defp session_json(session, extra \\ %{}) do
    base = %{
      id: session.id,
      name: session.name,
      agent_type: session.agent_type,
      status: session.status,
      execution_mode: session.execution_mode,
      project_id: session.project_id,
      host_id: session.host_id,
      inserted_at: session.inserted_at,
      last_used_at: session.last_used_at
    }

    Map.merge(base, extra)
  end

  defp message_json(msg) do
    %{id: msg.id, role: msg.role, content: msg.content, inserted_at: msg.inserted_at}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
