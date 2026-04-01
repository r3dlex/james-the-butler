defmodule James.HooksTest do
  use James.DataCase

  alias James.{Accounts, Hooks}

  defp create_user(email \\ "hook_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_hook(user, attrs \\ %{}) do
    {:ok, hook} =
      Hooks.create_hook(
        Map.merge(%{user_id: user.id, event: "post_tool_use", type: "http"}, attrs)
      )

    hook
  end

  describe "create_hook/1" do
    test "creates a hook record" do
      user = create_user()

      assert {:ok, hook} =
               Hooks.create_hook(%{
                 user_id: user.id,
                 event: "post_tool_use",
                 type: "http",
                 config: %{"url" => "https://example.com/webhook"}
               })

      assert hook.user_id == user.id
      assert hook.event == "post_tool_use"
      assert hook.type == "http"
    end

    test "defaults enabled to true" do
      user = create_user("hook_enabled@example.com")
      {:ok, hook} = Hooks.create_hook(%{user_id: user.id, event: "task_start", type: "command"})
      assert hook.enabled == true
    end

    test "defaults scope to account" do
      user = create_user("hook_scope@example.com")
      {:ok, hook} = Hooks.create_hook(%{user_id: user.id, event: "session_start", type: "http"})
      assert hook.scope == "account"
    end

    test "fails when user_id is missing" do
      assert {:error, changeset} =
               Hooks.create_hook(%{event: "post_tool_use", type: "http"})

      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when event is missing" do
      user = create_user("hook_no_event@example.com")
      assert {:error, changeset} = Hooks.create_hook(%{user_id: user.id, type: "http"})
      assert %{event: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when type is missing" do
      user = create_user("hook_no_type@example.com")

      assert {:error, changeset} =
               Hooks.create_hook(%{user_id: user.id, event: "post_tool_use"})

      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid event" do
      user = create_user("hook_bad_event@example.com")

      assert {:error, changeset} =
               Hooks.create_hook(%{user_id: user.id, event: "fake_event", type: "http"})

      assert %{event: [_]} = errors_on(changeset)
    end

    test "rejects invalid type" do
      user = create_user("hook_bad_type@example.com")

      assert {:error, changeset} =
               Hooks.create_hook(%{user_id: user.id, event: "post_tool_use", type: "webhook"})

      assert %{type: [_]} = errors_on(changeset)
    end

    test "stores matcher field" do
      user = create_user("hook_matcher@example.com")

      {:ok, hook} =
        Hooks.create_hook(%{
          user_id: user.id,
          event: "pre_tool_use",
          type: "command",
          matcher: "bash|python"
        })

      assert hook.matcher == "bash|python"
    end
  end

  describe "list_hooks/1" do
    test "returns hooks for user" do
      user = create_user("list_hooks@example.com")
      create_hook(user, %{event: "session_start"})
      create_hook(user, %{event: "task_start"})
      hooks = Hooks.list_hooks(user.id)
      assert length(hooks) == 2
    end

    test "does not return other users' hooks" do
      user1 = create_user("hook_u1@example.com")
      user2 = create_user("hook_u2@example.com")
      create_hook(user1)
      assert Hooks.list_hooks(user2.id) == []
    end

    test "returns empty list when no hooks" do
      user = create_user("no_hooks@example.com")
      assert Hooks.list_hooks(user.id) == []
    end
  end

  describe "update_hook/2" do
    test "updates the hook config" do
      user = create_user("update_hook@example.com")
      hook = create_hook(user)
      new_config = %{"url" => "https://new.example.com"}
      assert {:ok, updated} = Hooks.update_hook(hook, %{config: new_config})
      assert updated.config == new_config
    end

    test "updates the enabled field via enable_hook" do
      user = create_user("enable_hook@example.com")
      hook = create_hook(user)
      {:ok, _} = Hooks.disable_hook(hook)
      refreshed = Hooks.get_hook(hook.id)
      assert {:ok, enabled} = Hooks.enable_hook(refreshed)
      assert enabled.enabled == true
    end

    test "disable_hook sets enabled to false" do
      user = create_user("disable_hook@example.com")
      hook = create_hook(user)
      assert {:ok, disabled} = Hooks.disable_hook(hook)
      assert disabled.enabled == false
    end
  end

  describe "delete_hook/1" do
    test "removes the hook" do
      user = create_user("delete_hook@example.com")
      hook = create_hook(user)
      assert {:ok, _} = Hooks.delete_hook(hook)
      assert Hooks.get_hook(hook.id) == nil
    end
  end

  describe "Hook.valid_events/0 and Hook.valid_types/0" do
    alias James.Hooks.Hook

    test "valid_events returns a non-empty list of strings" do
      events = Hook.valid_events()
      assert is_list(events)
      assert events != []
      assert "session_start" in events
      assert "pre_tool_use" in events
    end

    test "valid_types returns a non-empty list of strings" do
      types = Hook.valid_types()
      assert is_list(types)
      assert "command" in types
      assert "http" in types
      assert "prompt" in types
      assert "agent" in types
    end
  end
end
