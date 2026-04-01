defmodule JamesWeb.ChannelConfigControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Channels}

  defp create_user(email \\ "chan_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_config(user, attrs \\ %{}) do
    {:ok, config} =
      Channels.create_channel_config(
        Map.merge(
          %{
            user_id: user.id,
            mcp_server: "telegram",
            config: %{bot_token: "test-token"}
          },
          attrs
        )
      )

    config
  end

  describe "GET /api/channel-configs (index)" do
    test "returns user's channel configs", %{conn: conn} do
      user = create_user()
      create_config(user)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/channel-configs")
      configs = json_response(conn, 200)["channel_configs"]
      assert configs != []
    end

    test "returns empty list when user has no configs", %{conn: conn} do
      user = create_user("chan_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/channel-configs")
      assert json_response(conn, 200)["channel_configs"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/channel-configs")
      assert conn.status == 401
    end
  end

  describe "POST /api/channel-configs (create)" do
    test "creates a channel config for authenticated user", %{conn: conn} do
      user = create_user("chan_create@example.com")
      conn = authed_conn(conn, user)

      conn =
        post(conn, "/api/channel-configs", %{
          mcp_server: "slack",
          config: %{webhook_url: "https://hooks.slack.com/test"}
        })

      assert json_response(conn, 201)["channel_config"]["mcp_server"] == "slack"
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/channel-configs", %{mcp_server: "slack"})
      assert conn.status == 401
    end
  end

  describe "DELETE /api/channel-configs/:id (delete)" do
    test "deletes a channel config", %{conn: conn} do
      user = create_user("chan_delete@example.com")
      config = create_config(user)
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/channel-configs/#{config.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown config", %{conn: conn} do
      user = create_user("chan_del_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/channel-configs/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
