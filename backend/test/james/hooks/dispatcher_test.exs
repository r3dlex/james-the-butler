defmodule James.Hooks.DispatcherTest do
  use James.DataCase

  alias James.{Accounts, Hooks}
  alias James.Hooks.Dispatcher

  defp create_user(email \\ "dispatcher_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_hook(user, attrs) do
    {:ok, hook} =
      Hooks.create_hook(
        Map.merge(
          %{user_id: user.id, event: "post_tool_use", type: "http", enabled: true},
          attrs
        )
      )

    hook
  end

  describe "fire/3 with no matching hooks" do
    test "returns :ok when user has no hooks for the event" do
      user = create_user()
      assert Dispatcher.fire(user.id, "post_tool_use", %{}) == :ok
    end

    test "returns :ok when hooks exist for a different event" do
      user = create_user("disp_other_event@example.com")

      create_hook(user, %{
        event: "session_start",
        type: "http",
        config: %{"url" => "https://example.com"}
      })

      assert Dispatcher.fire(user.id, "post_tool_use", %{}) == :ok
    end

    test "returns :ok when matching hook is disabled" do
      user = create_user("disp_disabled@example.com")

      create_hook(user, %{
        event: "post_tool_use",
        type: "http",
        config: %{"url" => "https://example.com"},
        enabled: false
      })

      assert Dispatcher.fire(user.id, "post_tool_use", %{tool_name: "bash"}) == :ok
    end
  end

  describe "fire/3 with http hook" do
    test "returns :ok (fire-and-forget, not :deny)" do
      user = create_user("disp_http@example.com")

      create_hook(user, %{
        event: "post_tool_use",
        type: "http",
        config: %{"url" => "https://httpbin.org/post"}
      })

      result = Dispatcher.fire(user.id, "post_tool_use", %{tool_name: "bash"})
      assert result == :ok
    end
  end

  describe "fire/3 with prompt hook" do
    test "returns {:modify, map} when prompt is set" do
      user = create_user("disp_prompt@example.com")

      create_hook(user, %{
        event: "pre_prompt_submit",
        type: "prompt",
        config: %{"prompt" => "Always be safe"}
      })

      result = Dispatcher.fire(user.id, "pre_prompt_submit", %{})
      assert {:modify, %{inject_prompt: "Always be safe"}} = result
    end

    test "returns :ok when prompt hook has empty prompt" do
      user = create_user("disp_empty_prompt@example.com")

      create_hook(user, %{
        event: "pre_prompt_submit",
        type: "prompt",
        config: %{"prompt" => ""}
      })

      assert Dispatcher.fire(user.id, "pre_prompt_submit", %{}) == :ok
    end
  end

  describe "fire/3 matcher patterns" do
    test "matches when tool_name is in pipe-separated pattern" do
      user = create_user("disp_matcher@example.com")

      create_hook(user, %{
        event: "pre_tool_use",
        type: "prompt",
        config: %{"prompt" => "Watch this tool"},
        matcher: "bash|python|node"
      })

      result = Dispatcher.fire(user.id, "pre_tool_use", %{tool_name: "python"})
      assert {:modify, _} = result
    end

    test "does not match when tool_name is not in pattern" do
      user = create_user("disp_no_match@example.com")

      create_hook(user, %{
        event: "pre_tool_use",
        type: "prompt",
        config: %{"prompt" => "Restricted"},
        matcher: "bash|python"
      })

      result = Dispatcher.fire(user.id, "pre_tool_use", %{tool_name: "ruby"})
      assert result == :ok
    end

    test "matches when matcher is nil (no filter)" do
      user = create_user("disp_nil_matcher@example.com")

      create_hook(user, %{
        event: "pre_tool_use",
        type: "prompt",
        config: %{"prompt" => "Always inject"},
        matcher: nil
      })

      result = Dispatcher.fire(user.id, "pre_tool_use", %{tool_name: "anything"})
      assert {:modify, _} = result
    end
  end
end
