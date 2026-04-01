defmodule JamesWeb.UserSocket do
  use Phoenix.Socket

  channel "session:*", JamesWeb.SessionChannel
  channel "planner:*", JamesWeb.PlannerChannel
  channel "host:*", JamesWeb.HostChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case James.Auth.verify_token(token) do
      {:ok, claims} ->
        user = James.Accounts.get_user(claims["sub"])

        if user do
          {:ok, assign(socket, :current_user, user)}
        else
          :error
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
