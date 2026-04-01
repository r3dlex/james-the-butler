defmodule James.ChannelsTest do
  use James.DataCase

  alias James.{Accounts, Channels}

  defp create_user(email \\ "channels_test@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_config(user, attrs \\ %{}) do
    {:ok, config} =
      Channels.create_channel_config(
        Map.merge(
          %{user_id: user.id, mcp_server: "telegram", config: %{bot_token: "tok"}},
          attrs
        )
      )

    config
  end

  describe "update_channel_config/2" do
    test "updates an existing channel config" do
      user = create_user("update_chan@example.com")
      config = create_config(user)

      assert {:ok, updated} =
               Channels.update_channel_config(config, %{config: %{bot_token: "new-tok"}})

      # Reload from DB to ensure JSONB string keys
      reloaded = Channels.get_channel_config(updated.id)
      assert reloaded.config["bot_token"] == "new-tok"
    end

    test "returns error changeset for invalid attrs" do
      user = create_user("invalid_chan@example.com")
      config = create_config(user)
      # mcp_server cannot be nil
      assert {:error, changeset} = Channels.update_channel_config(config, %{mcp_server: nil})
      assert %{mcp_server: _} = errors_on(changeset)
    end
  end

  describe "get_channel_config/1" do
    test "returns nil for unknown id" do
      assert is_nil(Channels.get_channel_config(Ecto.UUID.generate()))
    end

    test "returns config by id" do
      user = create_user("get_chan@example.com")
      config = create_config(user)
      found = Channels.get_channel_config(config.id)
      assert found.id == config.id
    end
  end

  describe "list_channel_configs/1" do
    test "returns configs for user" do
      user = create_user("list_chan@example.com")
      create_config(user, %{mcp_server: "slack"})
      create_config(user, %{mcp_server: "telegram"})
      configs = Channels.list_channel_configs(user.id)
      assert length(configs) == 2
    end
  end
end
