defmodule JamesWeb.PersonalityControllerTest do
  use JamesWeb.ConnCase

  alias James.Accounts

  defp create_user(email \\ "personality_ctrl@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email, name: "Personality User"})
    user
  end

  defp create_profile(user, attrs \\ %{}) do
    {:ok, profile} =
      Accounts.create_personality_profile(
        Map.merge(%{user_id: user.id, name: "My Profile", preset: "butler"}, attrs)
      )

    profile
  end

  describe "GET /api/personality/presets (presets)" do
    test "returns 200 with list of built-in presets", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/personality/presets")
      presets = json_response(conn, 200)["presets"]
      assert is_list(presets)
      ids = Enum.map(presets, & &1["id"])
      assert "butler" in ids
      assert "collaborator" in ids
      assert "analyst" in ids
      assert "coach" in ids
      assert "editor" in ids
      assert "silent" in ids
    end

    test "each preset has id, name, and prompt fields", %{conn: conn} do
      user = create_user("personality_preset_fields@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/personality/presets")
      [preset | _] = json_response(conn, 200)["presets"]
      assert Map.has_key?(preset, "id")
      assert Map.has_key?(preset, "name")
      assert Map.has_key?(preset, "prompt")
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/personality/presets")
      assert conn.status == 401
    end
  end

  describe "GET /api/personality/profiles (index)" do
    test "returns empty list when user has no profiles", %{conn: conn} do
      user = create_user("personality_empty@example.com")
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/personality/profiles")
      assert json_response(conn, 200)["profiles"] == []
    end

    test "returns user's custom profiles", %{conn: conn} do
      user = create_user("personality_list@example.com")
      create_profile(user, %{name: "Work Profile"})
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/personality/profiles")
      profiles = json_response(conn, 200)["profiles"]
      assert length(profiles) == 1
      assert hd(profiles)["name"] == "Work Profile"
    end

    test "does not return other users' profiles", %{conn: conn} do
      user1 = create_user("personality_owner@example.com")
      user2 = create_user("personality_other@example.com")
      create_profile(user2)
      conn = authed_conn(conn, user1)
      conn = get(conn, "/api/personality/profiles")
      assert json_response(conn, 200)["profiles"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/personality/profiles")
      assert conn.status == 401
    end
  end

  describe "POST /api/personality/profiles (create)" do
    test "creates a profile with valid params and returns 201", %{conn: conn} do
      user = create_user("personality_create@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/personality/profiles", %{name: "Butler Profile", preset: "butler"})
      profile = json_response(conn, 201)["profile"]
      assert profile["name"] == "Butler Profile"
      assert profile["preset"] == "butler"
    end

    test "returns 422 without required name", %{conn: conn} do
      user = create_user("personality_invalid@example.com")
      conn = authed_conn(conn, user)
      conn = post(conn, "/api/personality/profiles", %{preset: "butler"})
      assert conn.status == 422
      assert Map.has_key?(json_response(conn, 422), "errors")
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn = post(conn, "/api/personality/profiles", %{name: "Unauth"})
      assert conn.status == 401
    end

    test "created profile has expected fields", %{conn: conn} do
      user = create_user("personality_create_fields@example.com")
      conn = authed_conn(conn, user)

      conn =
        post(conn, "/api/personality/profiles", %{name: "Fields Profile", preset: "analyst"})

      profile = json_response(conn, 201)["profile"]
      assert Map.has_key?(profile, "id")
      assert Map.has_key?(profile, "name")
      assert Map.has_key?(profile, "preset")
      assert Map.has_key?(profile, "custom_prompt")
    end
  end

  describe "PUT /api/personality/profiles/:id (update)" do
    test "updates a profile and returns 200", %{conn: conn} do
      user = create_user("personality_update@example.com")
      profile = create_profile(user, %{name: "Old Name"})
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/personality/profiles/#{profile.id}", %{name: "New Name"})
      assert json_response(conn, 200)["profile"]["name"] == "New Name"
    end

    test "returns 404 for unknown profile", %{conn: conn} do
      user = create_user("personality_upd_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = put(conn, "/api/personality/profiles/#{Ecto.UUID.generate()}", %{name: "X"})
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 for another user's profile", %{conn: conn} do
      user1 = create_user("personality_upd_owner@example.com")
      user2 = create_user("personality_upd_other@example.com")
      profile = create_profile(user1)
      conn = authed_conn(conn, user2)
      conn = put(conn, "/api/personality/profiles/#{profile.id}", %{name: "X"})
      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "requires authentication", %{conn: conn} do
      conn = put(conn, "/api/personality/profiles/#{Ecto.UUID.generate()}", %{name: "X"})
      assert conn.status == 401
    end
  end

  describe "DELETE /api/personality/profiles/:id (delete)" do
    test "deletes a profile for its owner", %{conn: conn} do
      user = create_user("personality_delete@example.com")
      profile = create_profile(user)
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/personality/profiles/#{profile.id}")
      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 for unknown profile", %{conn: conn} do
      user = create_user("personality_del_notfound@example.com")
      conn = authed_conn(conn, user)
      conn = delete(conn, "/api/personality/profiles/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 403 for another user's profile", %{conn: conn} do
      user1 = create_user("personality_del_owner@example.com")
      user2 = create_user("personality_del_other@example.com")
      profile = create_profile(user1)
      conn = authed_conn(conn, user2)
      conn = delete(conn, "/api/personality/profiles/#{profile.id}")
      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "requires authentication", %{conn: conn} do
      conn = delete(conn, "/api/personality/profiles/#{Ecto.UUID.generate()}")
      assert conn.status == 401
    end
  end
end
