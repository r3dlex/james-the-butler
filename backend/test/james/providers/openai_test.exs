defmodule James.Providers.OpenAITest do
  use ExUnit.Case, async: true

  alias James.Providers.OpenAI

  describe "send_message/2" do
    test "returns error when OPENAI_API_KEY is not set" do
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)

      assert {:error, "OPENAI_API_KEY not configured"} =
               OpenAI.send_message([%{role: "user", content: "hi"}])
    end
  end

  describe "stream_message/2" do
    test "returns error when OPENAI_API_KEY is not set" do
      System.delete_env("OPENAI_API_KEY")
      Application.delete_env(:james, :openai_api_key)

      assert {:error, "OPENAI_API_KEY not configured"} =
               OpenAI.stream_message([%{role: "user", content: "hi"}])
    end
  end
end
