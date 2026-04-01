defmodule JamesWeb.PlannerChannelTest do
  use JamesWeb.ChannelCase

  alias James.{Accounts, Hosts, Sessions}

  defp create_user do
    {:ok, user} =
      Accounts.create_user(%{email: "planner_chan_#{System.unique_integer()}@example.com"})

    user
  end

  defp create_session(user) do
    {:ok, host} =
      Hosts.create_host(%{
        name: "planner-chan-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9200"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "Planner Chan Session"})

    session
  end

  describe "join planner channel" do
    test "joins successfully for own session" do
      user = create_user()
      session = create_session(user)
      socket = connect_socket(user)

      assert {:ok, _reply, _socket} =
               subscribe_and_join(socket, JamesWeb.PlannerChannel, "planner:#{session.id}")
    end

    test "rejects join for non-existent session" do
      user = create_user()
      socket = connect_socket(user)

      assert {:error, %{reason: "session not found"}} =
               subscribe_and_join(
                 socket,
                 JamesWeb.PlannerChannel,
                 "planner:#{Ecto.UUID.generate()}"
               )
    end

    test "rejects join for another user's session" do
      user1 = create_user()
      user2 = create_user()
      session = create_session(user1)
      socket = connect_socket(user2)

      assert {:error, %{reason: "forbidden"}} =
               subscribe_and_join(socket, JamesWeb.PlannerChannel, "planner:#{session.id}")
    end
  end

  describe "pubsub event relay" do
    test "relays planner_step events to client" do
      user = create_user()
      session = create_session(user)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.PlannerChannel, "planner:#{session.id}")

      step = %{type: "decomposing", description: "thinking..."}

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "planner:#{session.id}",
        {:planner_step, step}
      )

      assert_push("planner:step", %{step: %{type: "decomposing"}})
      _ = socket
    end

    test "relays task_list_updated events to client" do
      user = create_user()
      session = create_session(user)
      socket = connect_socket(user)

      {:ok, _, socket} =
        subscribe_and_join(socket, JamesWeb.PlannerChannel, "planner:#{session.id}")

      tasks = [%{id: "t1", description: "do it", status: "pending", risk_level: "read_only"}]

      Phoenix.PubSub.broadcast(
        James.PubSub,
        "planner:#{session.id}",
        {:task_list_updated, tasks}
      )

      assert_push("planner:tasks", %{tasks: [%{id: "t1"}]})
      _ = socket
    end
  end
end
