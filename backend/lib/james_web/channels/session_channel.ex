defmodule JamesWeb.SessionChannel do
  use Phoenix.Channel

  alias James.Sessions

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
        {:ok, %{messages: Enum.map(messages, &message_payload/1)}, assign(socket, :session_id, session_id)}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Subscribe to PubSub for this session to relay events to the client
    Phoenix.PubSub.subscribe(James.PubSub, "session:#{socket.assigns.session_id}")
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

  def handle_info({:task_updated, task}, socket) do
    push(socket, "task:updated", task_payload(task))
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
    %{id: task.id, description: task.description, status: task.status, risk_level: task.risk_level}
  end
end
