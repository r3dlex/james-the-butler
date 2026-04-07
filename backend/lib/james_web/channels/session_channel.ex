defmodule JamesWeb.SessionChannel do
  @moduledoc false
  use Phoenix.Channel

  alias James.Sessions
  alias James.Sessions.AwayDetector
  alias James.OpenClaw.Orchestrator
  alias James.Workers.GitStatusWorker
  alias James.Tasks

  @impl true
  def join("session:" <> session_id, _params, socket) do
    user = socket.assigns.current_user
    session = Sessions.get_session(session_id)

    cond do
      is_nil(session) ->
        {:error, %{reason: "session not found"}}

      session.user_id != user.id ->
        {:error, %{reason: "forbidden"}}

      true ->
        messages = Sessions.list_messages(session_id)
        send(self(), :after_join)

        {:ok, %{messages: Enum.map(messages, &message_payload/1)},
         assign(socket, :session_id, session_id)}
    end
  end

  # ---------------------------------------------------------------------------
  # message:new
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in("message:new", %{"content" => content, "session_id" => session_id}, socket) do
    socket_session_id = socket.assigns.session_id

    if session_id != socket_session_id do
      {:reply, {:error, :forbidden}, socket}
    else
      session = Sessions.get_session(socket_session_id)

      if is_nil(session) do
        {:reply, {:error, :session_not_found}, socket}
      else
        case Sessions.create_message(%{
               session_id: session_id,
               role: "user",
               content: content
             }) do
          {:ok, message} ->
            :ok =
              Phoenix.PubSub.broadcast(
                James.PubSub,
                "session:#{session_id}",
                {:user_message, message}
              )

            {:reply, :ok, socket}

          {:error, _changeset} ->
            {:reply, {:error, :internal_error}, socket}
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # task:approve / task:reject
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in("task:approve", %{"task_id" => task_id}, socket) do
    socket_session_id = socket.assigns.session_id

    case Tasks.get_task(task_id) do
      nil ->
        {:reply, {:error, :not_found}, socket}

      task ->
        if task.session_id != socket_session_id do
          {:reply, {:error, :forbidden}, socket}
        else
          {:ok, updated_task} = Tasks.update_task_status(task, "approved")

          :ok =
            Phoenix.PubSub.broadcast(
              James.PubSub,
              "session:#{socket_session_id}",
              {:task_updated, updated_task}
            )

          {:reply, :ok, socket}
        end
    end
  end

  @impl true
  def handle_in("task:reject", %{"task_id" => task_id}, socket) do
    socket_session_id = socket.assigns.session_id

    case Tasks.get_task(task_id) do
      nil ->
        {:reply, {:error, :not_found}, socket}

      task ->
        if task.session_id != socket_session_id do
          {:reply, {:error, :forbidden}, socket}
        else
          {:ok, updated_task} = Tasks.update_task_status(task, "rejected")

          :ok =
            Phoenix.PubSub.broadcast(
              James.PubSub,
              "session:#{socket_session_id}",
              {:task_updated, updated_task}
            )

          {:reply, :ok, socket}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # WebRTC signaling
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in("webrtc:offer", %{"sdp" => sdp, "session_id" => session_id}, socket) do
    # Forward the offer to the host's orchestrator.  The orchestrator broadcasts
    # {:webrtc_offer_received, sdp, viewer_id} to the session topic, where the
    # host's SessionChannel handle_info delivers it to the client as "webrtc:offer".
    # If the orchestrator does not know about this session yet (cold start) or
    # is not running (tests), we fall back to a direct broadcast so the host
    # can still pick up the offer.
    viewer_id = socket.assigns.current_user.id

    result =
      try do
        Orchestrator.handle_webrtc_offer(session_id, sdp, viewer_id)
      rescue
        UndefinedFunctionError -> {:error, :not_found}
      catch
        :exit, {:noproc, _} -> {:error, :not_found}
      end

    case result do
      {:error, :not_found} ->
        :ok =
          Phoenix.PubSub.broadcast(
            James.PubSub,
            "session:#{session_id}",
            {:webrtc_offer_received, sdp, viewer_id}
          )

        {:reply, :ok, socket}
    end
  end

  @impl true
  def handle_in("webrtc:answer", %{"sdp" => sdp, "session_id" => session_id}, socket) do
    :ok =
      Phoenix.PubSub.broadcast(James.PubSub, "session:#{session_id}", {:webrtc_answer, sdp})

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("webrtc:ice_candidate", payload, socket) do
    :ok =
      Phoenix.PubSub.broadcast(
        James.PubSub,
        "session:#{socket.assigns.session_id}",
        {:webrtc_ice_candidate, payload}
      )

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("session:resume", _params, socket) do
    session_id = socket.assigns.session_id

    case AwayDetector.on_resume(session_id) do
      {:inject, summary} ->
        {:ok, _} =
          Sessions.create_message(%{
            session_id: session_id,
            role: "planner",
            content: summary
          })

        push(socket, "away_summary", %{content: summary})

      :no_summary_needed ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Subscribe to PubSub for this session to relay events to the client
    Phoenix.PubSub.subscribe(James.PubSub, "session:#{socket.assigns.session_id}")

    # Enqueue git status fetch asynchronously if session has working directories
    session = Sessions.get_session(socket.assigns.session_id)

    if session && session.working_directories != [] do
      user = socket.assigns.current_user

      _task =
        James.TaskSupervisor
        |> Task.Supervisor.async_nolink(GitStatusWorker, :perform, [
          %Oban.Job{args: %{"session_id" => socket.assigns.session_id, "user_id" => user.id}}
        ])
    end

    {:noreply, socket}
  end

  def handle_info({:user_message, message}, socket) do
    push(socket, "message:new", message_payload(message))
    {:noreply, socket}
  end

  def handle_info({:assistant_chunk, chunk}, socket) do
    push(socket, "message:chunk", %{content: chunk})
    {:noreply, socket}
  end

  def handle_info({:assistant_message, message}, socket) do
    push(socket, "message:new", message_payload(message))
    {:noreply, socket}
  end

  def handle_info({:task_updated, task}, socket) do
    push(socket, "task:updated", task_payload(task))
    {:noreply, socket}
  end

  def handle_info({:webrtc_offer_received, sdp, viewer_id}, socket) do
    push(socket, "webrtc:offer", %{"sdp" => sdp, "from_viewer_id" => viewer_id})
    {:noreply, socket}
  end

  def handle_info({:webrtc_ice_candidate, payload}, socket) do
    push(socket, "webrtc:ice_candidate", payload)
    {:noreply, socket}
  end

  def handle_info({:artifact_created, artifact}, socket) do
    push(socket, "artifact:created", %{id: artifact.id, type: artifact.type, path: artifact.path})
    {:noreply, socket}
  end

  defp message_payload(msg) do
    %{id: msg.id, role: msg.role, content: msg.content, inserted_at: msg.inserted_at}
  end

  defp task_payload(task) do
    %{
      id: task.id,
      description: task.description,
      status: task.status,
      risk_level: task.risk_level
    }
  end
end
