defmodule James.Accounts.PersonalityProfileTest do
  use James.DataCase

  alias James.Accounts
  alias James.Accounts.PersonalityProfile

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
end
