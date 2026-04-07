defmodule JamesWeb.UserSocket do
  use Phoenix.Socket

  channel "session:*", JamesWeb.SessionChannel
  channel "planner:*", JamesWeb.PlannerChannel
  channel "host:*", JamesWeb.HostChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    IO.inspect(token, label: "WS_TOKEN")

    case James.Auth.verify_token(token) do
      {:ok, claims} ->
        IO.inspect(claims, label: "WS_CLAIMS")
        user = James.Accounts.get_user(claims["sub"])

        if user do
          IO.puts("WS_AUTH_SUCCESS user_id=#{user.id}")
          {:ok, assign(socket, :current_user, user)}
        else
          IO.puts("WS_AUTH_FAILED user_not_found sub=#{claims["sub"]}")
          :error
        end

      {:error, reason} ->
        IO.inspect(reason, label: "WS_TOKEN_ERROR")
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
