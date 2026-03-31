defmodule JamesWeb.PlannerChannel do
  use Phoenix.Channel

  alias James.Sessions

  @impl true
  def join("planner:" <> session_id, _params, socket) do
    user = socket.assigns.current_user
    session = Sessions.get_session(session_id)

    cond do
      is_nil(session) ->
        {:error, %{reason: "session not found"}}

      session.user_id != user.id ->
        {:error, %{reason: "forbidden"}}

      true ->
        Phoenix.PubSub.subscribe(James.PubSub, "planner:#{session_id}")
        {:ok, assign(socket, :session_id, session_id)}
    end
  end

  @impl true
  def handle_info({:planner_step, step}, socket) do
    push(socket, "planner:step", %{step: step})
    {:noreply, socket}
  end

  def handle_info({:task_list_updated, tasks}, socket) do
    push(socket, "planner:tasks", %{tasks: tasks})
    {:noreply, socket}
  end
end
