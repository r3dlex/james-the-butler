defmodule James.Providers.AnthropicTest do
  use ExUnit.Case, async: false

  alias James.Providers.Anthropic

  setup do
    original_key = Application.get_env(:james, :anthropic_api_key)
    original_env = System.get_env("ANTHROPIC_API_KEY")

    Application.delete_env(:james, :anthropic_api_key)
    System.delete_env("ANTHROPIC_API_KEY")

    on_exit(fn ->
      case original_key do
        nil -> Application.delete_env(:james, :anthropic_api_key)
        v -> Application.put_env(:james, :anthropic_api_key, v)
      end

      case original_env do
        nil -> System.delete_env("ANTHROPIC_API_KEY")
        v -> System.put_env("ANTHROPIC_API_KEY", v)
      end
    end)

    :ok
  end

  describe "stream_message/2 — no API key" do
    test "returns error when ANTHROPIC_API_KEY is not configured" do
      assert {:error, reason} = Anthropic.stream_message([%{role: "user", content: "hi"}])
      assert reason =~ "not configured"
    end

    test "returns error tuple for empty messages list when no key is set" do
      assert {:error, _} = Anthropic.stream_message([])
    end
  end

  describe "send_message/2 — no API key" do
    test "returns error when ANTHROPIC_API_KEY is not configured" do
      assert {:error, reason} = Anthropic.send_message([%{role: "user", content: "hello"}])
      assert reason =~ "not configured"
    end
  end
end
