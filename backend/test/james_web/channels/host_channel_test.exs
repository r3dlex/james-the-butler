defmodule JamesWeb.HostChannelTest do
  use JamesWeb.ChannelCase

  alias James.Accounts

  defp create_user do
    {:ok, user} =
      Accounts.create_user(%{email: "host_chan_#{System.unique_integer()}@example.com"})

    user
  end

  describe "join host channel" do
    test "joins successfully for any host_id" do
      user = create_user()
      socket = connect_socket(user)
      host_id = Ecto.UUID.generate()

      assert {:ok, _reply, _socket} =
               subscribe_and_join(socket, JamesWeb.HostChannel, "host:#{host_id}")
    end
  end

  describe "pubsub event relay" do
    test "relays host_status_changed events to client" do
      user = create_user()
      socket = connect_socket(user)
      host_id = Ecto.UUID.generate()

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.HostChannel, "host:#{host_id}")

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "host:#{host_id}",
        {:host_status_changed, "degraded"}
      )

      assert_push("host:status", %{status: "degraded"})
      _ = socket
    end

    test "relays session_routed events to client" do
      user = create_user()
      socket = connect_socket(user)
      host_id = Ecto.UUID.generate()

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.HostChannel, "host:#{host_id}")

      session_id = Ecto.UUID.generate()

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "host:#{host_id}",
        {:session_routed, session_id}
      )

      assert_push("host:session_routed", %{session_id: ^session_id})
      _ = socket
    end
  end
end
