defmodule James.Providers.AnthropicMinimaxTest do
  @moduledoc """
  Tests that the Anthropic SSE parser correctly handles MiniMax-style responses
  that include thinking blocks before the text content block.

  Thinking blocks (thinking_delta, signature_delta) must be silently ignored
  while text_delta content is accumulated normally.
  """

  use ExUnit.Case, async: true

  # process_events/3 and finalize_result/1 are private; we test via the public
  # parse_and_process helper that drives the same accumulator pipeline.
  #
  # Since the functions are private we exercise them through a thin wrapper
  # that calls the module internals via the parse_sse path used in production.

  # We extract the private functions indirectly by building a minimal SSE
  # binary payload (newline-delimited) and calling a real Bypass-backed
  # stream_message — but that requires network setup.
  #
  # Instead we use the module's public parse path: we call
  # Anthropic.stream_message with a Bypass server that responds with the
  # MiniMax-style SSE payload. The returned %{content:} must be "Hello!".

  alias James.Providers.Anthropic

  @minimax_events [
    %{
      "type" => "message_start",
      "message" => %{"usage" => %{"input_tokens" => 10}}
    },
    %{
      "type" => "content_block_start",
      "content_block" => %{"type" => "thinking", "thinking" => ""}
    },
    %{
      "type" => "content_block_delta",
      "delta" => %{"type" => "thinking_delta", "thinking" => "Let me think..."}
    },
    %{
      "type" => "content_block_delta",
      "delta" => %{"type" => "signature_delta", "signature" => "abc123"}
    },
    %{"type" => "content_block_stop"},
    %{
      "type" => "content_block_start",
      "content_block" => %{"type" => "text", "text" => ""}
    },
    %{
      "type" => "content_block_delta",
      "delta" => %{"type" => "text_delta", "text" => "Hello!"}
    },
    %{"type" => "content_block_stop"},
    %{
      "type" => "message_delta",
      "usage" => %{"output_tokens" => 5},
      "delta" => %{"stop_reason" => "end_turn"}
    }
  ]

  defp build_sse_body(events) do
    Enum.map_join(events, "", fn event ->
      "event: #{event["type"]}\ndata: #{Jason.encode!(event)}\n\n"
    end)
  end

  describe "MiniMax-style SSE response with thinking blocks" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "accumulates only text content, ignores thinking blocks", %{bypass: bypass} do
      sse_body = build_sse_body(@minimax_events)

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, sse_body)
      end)

      url = "http://localhost:#{bypass.port}"
      messages = [%{role: "user", content: "Hi"}]

      assert {:ok, result} =
               Anthropic.stream_message(messages,
                 api_key: "test-minimax-key",
                 base_url: url
               )

      assert result.content == "Hello!"
    end

    test "content is non-empty after processing MiniMax events with thinking blocks", %{
      bypass: bypass
    } do
      sse_body = build_sse_body(@minimax_events)

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, sse_body)
      end)

      url = "http://localhost:#{bypass.port}"
      messages = [%{role: "user", content: "Hi"}]

      assert {:ok, result} =
               Anthropic.stream_message(messages,
                 api_key: "test-minimax-key",
                 base_url: url
               )

      refute result.content == ""
      refute is_nil(result.content)
    end

    test "usage tokens are correctly accumulated from MiniMax events", %{bypass: bypass} do
      sse_body = build_sse_body(@minimax_events)

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, sse_body)
      end)

      url = "http://localhost:#{bypass.port}"
      messages = [%{role: "user", content: "Hi"}]

      assert {:ok, result} =
               Anthropic.stream_message(messages,
                 api_key: "test-minimax-key",
                 base_url: url
               )

      assert result.usage.input_tokens == 10
      assert result.usage.output_tokens == 5
    end

    test "stop_reason is set from message_delta", %{bypass: bypass} do
      sse_body = build_sse_body(@minimax_events)

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, sse_body)
      end)

      url = "http://localhost:#{bypass.port}"
      messages = [%{role: "user", content: "Hi"}]

      assert {:ok, result} =
               Anthropic.stream_message(messages,
                 api_key: "test-minimax-key",
                 base_url: url
               )

      assert result.stop_reason == "end_turn"
    end

    test "thinking block followed by multiple text deltas accumulates all text", %{bypass: bypass} do
      events = [
        %{"type" => "message_start", "message" => %{"usage" => %{"input_tokens" => 5}}},
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "thinking", "thinking" => ""}
        },
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "thinking_delta", "thinking" => "Thinking deeply..."}
        },
        %{"type" => "content_block_stop"},
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "text", "text" => ""}
        },
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "text_delta", "text" => "Part1"}
        },
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "text_delta", "text" => " Part2"}
        },
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "text_delta", "text" => " Part3"}
        },
        %{"type" => "content_block_stop"},
        %{
          "type" => "message_delta",
          "usage" => %{"output_tokens" => 3},
          "delta" => %{"stop_reason" => "end_turn"}
        }
      ]

      sse_body = build_sse_body(events)

      Bypass.expect_once(bypass, "POST", "/v1/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, sse_body)
      end)

      url = "http://localhost:#{bypass.port}"
      messages = [%{role: "user", content: "Hi"}]

      assert {:ok, result} =
               Anthropic.stream_message(messages,
                 api_key: "test-minimax-key",
                 base_url: url
               )

      assert result.content == "Part1 Part2 Part3"
    end
  end
end
