defmodule James.Accounts.PersonalityProfileTest do
  use James.DataCase

  alias James.Accounts
  alias James.Accounts.PersonalityProfile
  alias James.Personality

  defp create_user(email \\ "profile_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  describe "changeset/2" do
    test "valid changeset with name" do
      user = create_user()
      attrs = %{user_id: user.id, name: "My Profile"}
      changeset = PersonalityProfile.changeset(%PersonalityProfile{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without name" do
      user = create_user("noname@example.com")
      attrs = %{user_id: user.id}
      changeset = PersonalityProfile.changeset(%PersonalityProfile{}, attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid changeset with preset and custom_prompt" do
      user = create_user("preset@example.com")

      attrs = %{
        user_id: user.id,
        name: "Custom Butler",
        preset: "butler",
        custom_prompt: "Speak formally at all times."
      }

      changeset = PersonalityProfile.changeset(%PersonalityProfile{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset without preset or custom_prompt (optional fields)" do
      user = create_user("minimal@example.com")
      attrs = %{user_id: user.id, name: "Minimal Profile"}
      changeset = PersonalityProfile.changeset(%PersonalityProfile{}, attrs)
      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD via Accounts context
  # ---------------------------------------------------------------------------

  describe "create_personality_profile/1" do
    test "creates a profile with a custom_prompt" do
      user = create_user("crud_create_custom@example.com")

      assert {:ok, profile} =
               Accounts.create_personality_profile(%{
                 user_id: user.id,
                 name: "Custom Profile",
                 custom_prompt: "You are a concise assistant."
               })

      assert profile.name == "Custom Profile"
      assert profile.custom_prompt == "You are a concise assistant."
      assert profile.user_id == user.id
    end

    test "creates a preset-based profile storing the preset name" do
      user = create_user("crud_create_preset@example.com")

      assert {:ok, profile} =
               Accounts.create_personality_profile(%{
                 user_id: user.id,
                 name: "Butler Preset",
                 preset: "butler"
               })

      assert profile.preset == "butler"
    end

    test "creates a collaborator preset profile" do
      user = create_user("crud_create_collab@example.com")

      assert {:ok, profile} =
               Accounts.create_personality_profile(%{
                 user_id: user.id,
                 name: "Collab Preset",
                 preset: "collaborator"
               })

      assert profile.preset == "collaborator"
    end

    test "returns error when name is missing" do
      user = create_user("crud_create_noname@example.com")
      assert {:error, changeset} = Accounts.create_personality_profile(%{user_id: user.id})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_personality_profile/2" do
    test "updates the prompt text" do
      user = create_user("crud_update@example.com")

      {:ok, profile} =
        Accounts.create_personality_profile(%{
          user_id: user.id,
          name: "To Update",
          custom_prompt: "Original prompt."
        })

      assert {:ok, updated} =
               Accounts.update_personality_profile(profile, %{
                 custom_prompt: "Updated prompt."
               })

      assert updated.custom_prompt == "Updated prompt."
    end

    test "updates the name" do
      user = create_user("crud_update_name@example.com")

      {:ok, profile} =
        Accounts.create_personality_profile(%{user_id: user.id, name: "Old Name"})

      assert {:ok, updated} = Accounts.update_personality_profile(profile, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_personality_profile/1" do
    test "removes the profile from the database" do
      user = create_user("crud_delete@example.com")

      {:ok, profile} =
        Accounts.create_personality_profile(%{user_id: user.id, name: "To Delete"})

      assert {:ok, _} = Accounts.delete_personality_profile(profile)
      assert Accounts.get_personality_profile(profile.id) == nil
    end
  end

  describe "list_personality_profiles/1" do
    test "returns only the specified user's profiles" do
      user1 = create_user("crud_list_u1@example.com")
      user2 = create_user("crud_list_u2@example.com")

      {:ok, _} = Accounts.create_personality_profile(%{user_id: user1.id, name: "U1 Profile"})
      {:ok, _} = Accounts.create_personality_profile(%{user_id: user2.id, name: "U2 Profile"})

      profiles = Accounts.list_personality_profiles(user1)
      assert length(profiles) == 1
      assert hd(profiles).name == "U1 Profile"
    end

    test "returns empty list when user has no profiles" do
      user = create_user("crud_list_empty@example.com")
      assert Accounts.list_personality_profiles(user) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Personality.presets/0
  # ---------------------------------------------------------------------------

  describe "Personality.presets/0" do
    test "returns 6 presets" do
      assert length(Personality.presets()) == 6
    end

    test "returns all expected preset identifiers" do
      ids = Enum.map(Personality.presets(), & &1.id)
      assert "butler" in ids
      assert "collaborator" in ids
      assert "analyst" in ids
      assert "coach" in ids
      assert "editor" in ids
      assert "silent" in ids
    end

    test "each preset has id, name, and prompt" do
      Enum.each(Personality.presets(), fn preset ->
        assert is_binary(preset.id)
        assert is_binary(preset.name)
        assert is_binary(preset.prompt)
      end)
    end
  end
end
