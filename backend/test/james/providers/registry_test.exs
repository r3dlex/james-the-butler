defmodule James.Providers.RegistryTest do
  use ExUnit.Case, async: true

  alias James.Providers.Registry

  describe "provider_for_model/1 — Anthropic models" do
    test "returns Anthropic for claude-sonnet-4-20250514" do
      assert Registry.provider_for_model("claude-sonnet-4-20250514") ==
               {:ok, James.Providers.Anthropic}
    end

    test "returns Anthropic for claude-opus-4-20250514" do
      assert Registry.provider_for_model("claude-opus-4-20250514") ==
               {:ok, James.Providers.Anthropic}
    end
  end

  describe "provider_for_model/1 — OpenAI models" do
    test "returns OpenAI for gpt-4o" do
      assert Registry.provider_for_model("gpt-4o") == {:ok, James.Providers.OpenAI}
    end

    test "returns OpenAI for gpt-3.5-turbo" do
      assert Registry.provider_for_model("gpt-3.5-turbo") == {:ok, James.Providers.OpenAI}
    end
  end

  describe "provider_for_model/1 — Gemini models" do
    test "returns Gemini for gemini-2.0-flash" do
      assert Registry.provider_for_model("gemini-2.0-flash") == {:ok, James.Providers.Gemini}
    end
  end

  describe "provider_for_model/1 — MiniMax models" do
    test "MiniMax-M2.7 resolves to Anthropic (Anthropic-compatible API)" do
      assert Registry.provider_for_model("MiniMax-M2.7") == {:ok, James.Providers.Anthropic}
    end

    test "MiniMax-M2.5-highspeed resolves to Anthropic" do
      assert Registry.provider_for_model("MiniMax-M2.5-highspeed") ==
               {:ok, James.Providers.Anthropic}
    end
  end

  describe "provider_for_model/1 — unknown models" do
    test "returns error for unknown model" do
      assert Registry.provider_for_model("unknown-model") == {:error, :unknown_provider}
    end
  end

  describe "list_providers/0" do
    test "returns all registered provider modules" do
      providers = Registry.list_providers()
      assert is_list(providers)
      assert James.Providers.Anthropic in providers
      assert James.Providers.OpenAI in providers
      assert James.Providers.Gemini in providers
    end
  end

  describe "register_custom/2" do
    test "allows registering a custom prefix to provider mapping" do
      defmodule TestCustomProvider do
        @moduledoc false
      end

      :ok = Registry.register_custom("custom-llm", TestCustomProvider)
      assert Registry.provider_for_model("custom-llm-v1") == {:ok, TestCustomProvider}
    end

    test "custom registration does not affect built-in mappings" do
      :ok = Registry.register_custom("my-prefix", James.Providers.OpenAI)

      assert Registry.provider_for_model("claude-sonnet-4-20250514") ==
               {:ok, James.Providers.Anthropic}
    end
  end
end
