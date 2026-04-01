defmodule JamesWeb.HostChannel do
  @moduledoc false
  use Phoenix.Channel

  @impl true
  def join("host:" <> host_id, _params, socket) do
    Phoenix.PubSub.subscribe(James.PubSub, "host:#{host_id}")
    {:ok, assign(socket, :host_id, host_id)}
  end

  @impl true
  def handle_info({:host_status_changed, status}, socket) do
    push(socket, "host:status", %{host_id: socket.assigns.host_id, status: status})
    {:noreply, socket}
  end

  def handle_info({:session_routed, session_id}, socket) do
    push(socket, "host:session_routed", %{session_id: session_id})
    {:noreply, socket}
  end
end
