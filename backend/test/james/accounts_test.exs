defmodule James.AccountsTest do
  use James.DataCase

  alias James.Accounts

  describe "create_user/1" do
    test "creates a user with email and name" do
      assert {:ok, user} = Accounts.create_user(%{email: "alice@example.com", name: "Alice"})
      assert user.email == "alice@example.com"
      assert user.name == "Alice"
    end

    test "creates a user with email only" do
      assert {:ok, user} = Accounts.create_user(%{email: "bob@example.com"})
      assert user.email == "bob@example.com"
      assert user.name == nil
    end

    test "fails when email is missing" do
      assert {:error, changeset} = Accounts.create_user(%{name: "No Email"})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails on duplicate email" do
      {:ok, _} = Accounts.create_user(%{email: "dup@example.com"})
      assert {:error, changeset} = Accounts.create_user(%{email: "dup@example.com"})
      assert %{email: [_]} = errors_on(changeset)
    end

    test "defaults execution_mode to direct" do
      {:ok, user} = Accounts.create_user(%{email: "mode@example.com"})
      assert user.execution_mode == "direct"
    end

    test "rejects invalid execution_mode" do
      assert {:error, changeset} =
               Accounts.create_user(%{email: "bad@example.com", execution_mode: "invalid"})

      assert %{execution_mode: [_]} = errors_on(changeset)
    end
  end

  describe "get_user/1" do
    test "returns user by UUID" do
      {:ok, user} = Accounts.create_user(%{email: "get@example.com"})
      assert found = Accounts.get_user(user.id)
      assert found.id == user.id
    end

    test "returns nil for unknown UUID" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_user_by_email/1" do
    test "finds user by email" do
      {:ok, user} = Accounts.create_user(%{email: "find@example.com"})
      assert found = Accounts.get_user_by_email("find@example.com")
      assert found.id == user.id
    end

    test "returns nil for unknown email" do
      assert Accounts.get_user_by_email("nobody@example.com") == nil
    end
  end

  describe "update_user/2" do
    test "updates name field" do
      {:ok, user} = Accounts.create_user(%{email: "update@example.com", name: "Old Name"})
      assert {:ok, updated} = Accounts.update_user(user, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "updates execution_mode" do
      {:ok, user} = Accounts.create_user(%{email: "mode2@example.com"})
      assert {:ok, updated} = Accounts.update_user(user, %{execution_mode: "confirmed"})
      assert updated.execution_mode == "confirmed"
    end

    test "fails on invalid execution_mode" do
      {:ok, user} = Accounts.create_user(%{email: "invalid_mode@example.com"})
      assert {:error, changeset} = Accounts.update_user(user, %{execution_mode: "turbo"})
      assert %{execution_mode: [_]} = errors_on(changeset)
    end
  end

  describe "find_or_create_user_by_oauth/3" do
    test "creates a new user when none exists for provider+uid" do
      assert {:ok, user} =
               Accounts.find_or_create_user_by_oauth("github", "uid-001", %{
                 email: "oauth_new@example.com"
               })

      assert user.oauth_provider == "github"
      assert user.oauth_uid == "uid-001"
      assert user.email == "oauth_new@example.com"
    end

    test "returns existing user when found by provider+uid" do
      {:ok, existing} =
        Accounts.find_or_create_user_by_oauth("google", "uid-002", %{
          email: "oauth_existing@example.com"
        })

      assert {:ok, found} =
               Accounts.find_or_create_user_by_oauth("google", "uid-002", %{
                 email: "other@example.com"
               })

      assert found.id == existing.id
    end

    test "does not create a duplicate when called twice with same provider+uid" do
      {:ok, _} =
        Accounts.find_or_create_user_by_oauth("github", "uid-003", %{
          email: "nodup@example.com"
        })

      assert {:ok, _} =
               Accounts.find_or_create_user_by_oauth("github", "uid-003", %{
                 email: "nodup@example.com"
               })
    end

    test "fails to create when email is missing" do
      assert {:error, _changeset} =
               Accounts.find_or_create_user_by_oauth("github", "uid-noemail", %{name: "No Email"})
    end
  end
end
