defmodule JamesWeb.UserSocketTest do
  use JamesWeb.ChannelCase

  alias James.Accounts

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: "socket_#{System.unique_integer()}@example.com"})
    user
  end

  describe "connect/3" do
    test "connects successfully with a valid token" do
      user = create_user()
      {:ok, token} = James.Auth.generate_token(user)

      assert {:ok, socket} = connect(JamesWeb.UserSocket, %{"token" => token})
      assert socket.assigns.current_user.id == user.id
    end

    test "rejects connection with an invalid token" do
      assert :error = connect(JamesWeb.UserSocket, %{"token" => "bad-token"})
    end

    test "rejects connection when no token is provided" do
      assert :error = connect(JamesWeb.UserSocket, %{})
    end

    test "rejects connection for a non-existent user" do
      # Generate a token with a valid structure but for a user_id that doesn't exist
      fake_id = Ecto.UUID.generate()
      {:ok, token} = James.Auth.generate_token(%{id: fake_id})
      assert :error = connect(JamesWeb.UserSocket, %{"token" => token})
    end
  end

  describe "id/1" do
    test "returns user_socket:<user_id>" do
      user = create_user()
      {:ok, token} = James.Auth.generate_token(user)
      {:ok, socket} = connect(JamesWeb.UserSocket, %{"token" => token})

      assert JamesWeb.UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
