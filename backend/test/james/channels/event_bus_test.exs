defmodule James.Channels.EventBusTest do
  use James.DataCase

  alias James.{Accounts, Channels, Sessions}
  alias James.Channels.EventBus

  defp create_user(email \\ "eventbus_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "EventBus Session"})
    session
  end

  defp create_channel_config(user, attrs \\ %{}) do
    {:ok, config} =
      Channels.create_channel_config(
        Map.merge(%{user_id: user.id, mcp_server: "test-mcp"}, attrs)
      )

    config
  end

  describe "route_event/2" do
    test "returns {:error, :channel_not_found} for unknown channel config id" do
      assert {:error, :channel_not_found} =
               EventBus.route_event(Ecto.UUID.generate(), %{content: "hello"})
    end

    test "returns {:error, :no_session} when channel config has no session_id" do
      user = create_user()
      config = create_channel_config(user, %{session_id: nil})
      assert {:error, :no_session} = EventBus.route_event(config.id, %{content: "hello"})
    end

    test "returns {:ok, :routed} when session_id is set and sender rules allow all" do
      user = create_user("eventbus_route@example.com")
      session = create_session(user)

      config =
        create_channel_config(user, %{
          session_id: session.id,
          sender_rules: %{"allow_all" => true}
        })

      assert {:ok, :routed} = EventBus.route_event(config.id, %{content: "hello"})
    end

    test "returns {:ok, :routed} when sender_rules is empty map" do
      user = create_user("eventbus_empty_rules@example.com")
      session = create_session(user)
      config = create_channel_config(user, %{session_id: session.id, sender_rules: %{}})
      assert {:ok, :routed} = EventBus.route_event(config.id, %{content: "hello"})
    end

    test "returns {:error, :denied_by_rules} when sender not in allowed_senders" do
      user = create_user("eventbus_denied@example.com")
      session = create_session(user)

      config =
        create_channel_config(user, %{
          session_id: session.id,
          sender_rules: %{"allowed_senders" => ["trusted-bot"]}
        })

      assert {:error, :denied_by_rules} =
               EventBus.route_event(config.id, %{content: "hello", sender: "untrusted"})
    end

    test "returns {:ok, :routed} when sender is in allowed_senders" do
      user = create_user("eventbus_allowed@example.com")
      session = create_session(user)

      config =
        create_channel_config(user, %{
          session_id: session.id,
          sender_rules: %{"allowed_senders" => ["trusted-bot", "another-bot"]}
        })

      assert {:ok, :routed} =
               EventBus.route_event(config.id, %{content: "hello", sender: "trusted-bot"})
    end

    test "returns {:error, :denied_by_rules} when event sender is missing and allowed_senders is set" do
      user = create_user("eventbus_no_sender@example.com")
      session = create_session(user)

      config =
        create_channel_config(user, %{
          session_id: session.id,
          sender_rules: %{"allowed_senders" => ["trusted-bot"]}
        })

      # No :sender key in event — defaults to empty string which is not in the list
      assert {:error, :denied_by_rules} = EventBus.route_event(config.id, %{content: "hello"})
    end
  end
end
