defmodule JamesWeb.ProviderControllerTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, ProviderSettings}

  defp create_user(email \\ "provider_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_anthropic_config(user) do
    {:ok, config} =
      ProviderSettings.create_provider_config(%{
        user_id: user.id,
        provider_type: "anthropic",
        display_name: "Test Anthropic",
        api_key: "sk-ant-test",
        auth_method: "api_key"
      })

    config
  end

  defp create_ollama_config(user, base_url) do
    {:ok, config} =
      ProviderSettings.create_provider_config(%{
        user_id: user.id,
        provider_type: "ollama",
        display_name: "Test Ollama",
        base_url: base_url,
        auth_method: "none"
      })

    config
  end

  # ---------------------------------------------------------------------------
  # POST /api/providers/:id/test — success
  # ---------------------------------------------------------------------------

  describe "POST /api/providers/:id/test — connected" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns 200 with status=connected and latency_ms", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn c ->
        c
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "content" => [%{"type" => "text", "text" => "hi"}],
            "usage" => %{"input_tokens" => 1, "output_tokens" => 1}
          })
        )
      end)

      user = create_user("pc_connected@example.com")
      # Create a config whose base_url points to our Bypass mock
      {:ok, config} =
        ProviderSettings.create_provider_config(%{
          user_id: user.id,
          provider_type: "anthropic",
          display_name: "Mock Anthropic",
          api_key: "sk-ant-test",
          auth_method: "api_key",
          base_url: "http://localhost:#{bypass.port}"
        })

      conn = authed_conn(conn, user)
      conn = post(conn, "/api/providers/#{config.id}/test", %{})
      body = json_response(conn, 200)
      assert body["status"] == "connected"
      assert is_integer(body["latency_ms"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/providers/:id/test — failed (invalid key → 401)
  # ---------------------------------------------------------------------------

  describe "POST /api/providers/:id/test — failed" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns 200 with status=failed and reason when provider returns 401", %{
      conn: conn,
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "POST", "/v1/messages", fn c ->
        c
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      user = create_user("pc_failed@example.com")

      {:ok, config} =
        ProviderSettings.create_provider_config(%{
          user_id: user.id,
          provider_type: "anthropic",
          display_name: "Bad Key Anthropic",
          api_key: "sk-bad-key",
          auth_method: "api_key",
          base_url: "http://localhost:#{bypass.port}"
        })

      conn = authed_conn(conn, user)
      conn = post(conn, "/api/providers/#{config.id}/test", %{})
      body = json_response(conn, 200)
      assert body["status"] == "failed"
      assert is_binary(body["reason"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/providers/:id/test — 404
  # ---------------------------------------------------------------------------

  describe "POST /api/providers/:id/test — not found" do
    test "returns 404 for non-existent provider config", %{conn: conn} do
      user = create_user("pc_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/providers/#{Ecto.UUID.generate()}/test", %{})
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/providers/:id/test — requires auth
  # ---------------------------------------------------------------------------

  describe "POST /api/providers/:id/test — authentication" do
    test "requires authentication", %{conn: conn} do
      user = create_user("pc_auth_test@example.com")
      config = create_anthropic_config(user)
      conn = post(conn, "/api/providers/#{config.id}/test", %{})
      assert conn.status == 401
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/providers/:id/models — cloud provider
  # ---------------------------------------------------------------------------

  describe "GET /api/providers/:id/models — anthropic" do
    test "returns list of Claude models", %{conn: conn} do
      user = create_user("pc_models_cloud@example.com")
      config = create_anthropic_config(user)
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/providers/#{config.id}/models")
      body = json_response(conn, 200)
      assert is_list(body["models"])
      assert Enum.any?(body["models"], &String.starts_with?(&1, "claude-"))
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/providers/:id/models — local provider (Ollama via Bypass)
  # ---------------------------------------------------------------------------

  describe "GET /api/providers/:id/models — ollama" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "queries /api/tags and returns model names", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/tags", fn c ->
        body =
          Jason.encode!(%{
            "models" => [%{"name" => "llama3:latest"}, %{"name" => "mistral:7b"}]
          })

        c
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      user = create_user("pc_models_ollama@example.com")
      config = create_ollama_config(user, "http://localhost:#{bypass.port}")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/providers/#{config.id}/models")
      body = json_response(conn, 200)
      assert "llama3:latest" in body["models"]
      assert "mistral:7b" in body["models"]
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/providers/:id/models — 404
  # ---------------------------------------------------------------------------

  describe "GET /api/providers/:id/models — not found" do
    test "returns 404 for non-existent provider config", %{conn: conn} do
      user = create_user("pc_models_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/providers/#{Ecto.UUID.generate()}/models")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/providers/:id/models — requires auth
  # ---------------------------------------------------------------------------

  describe "GET /api/providers/:id/models — authentication" do
    test "requires authentication", %{conn: conn} do
      user = create_user("pc_models_auth@example.com")
      config = create_anthropic_config(user)
      conn = get(conn, "/api/providers/#{config.id}/models")
      assert conn.status == 401
    end
  end
end
