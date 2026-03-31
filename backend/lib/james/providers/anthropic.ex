defmodule James.Providers.Anthropic do
  @moduledoc """
  Streaming HTTP client for the Anthropic Messages API.
  Parses SSE events and calls a callback for each content delta.
  """

  @default_model "claude-sonnet-4-20250514"
  @default_url "https://api.anthropic.com"

  @doc """
  Sends a streaming chat completion request to the Anthropic API.

  Options:
    - `:model` — model identifier (default: claude-sonnet-4-20250514)
    - `:system` — system prompt string
    - `:max_tokens` — max response tokens (default: 4096)
    - `:tools` — list of tool definition maps for tool use
    - `:on_chunk` — `fn chunk_text -> :ok end` called for each content delta
    - `:on_done` — `fn usage_map -> :ok end` called when stream completes

  Returns `{:ok, %{content: String.t() | list(), usage: map(), stop_reason: String.t()}}` or `{:error, reason}`.
  When tools are in use and the model invokes one, `content` is a list of content blocks
  (text and tool_use maps) and `stop_reason` is `"tool_use"`.
  """
  def stream_message(messages, opts \\ []) do
    api_key = api_key()
    api_url = api_url()

    if is_nil(api_key) do
      {:error, "ANTHROPIC_API_KEY not configured"}
    else
      model = Keyword.get(opts, :model, @default_model)
      system = Keyword.get(opts, :system)
      max_tokens = Keyword.get(opts, :max_tokens, 4096)
      tools = Keyword.get(opts, :tools)
      on_chunk = Keyword.get(opts, :on_chunk, fn _ -> :ok end)

      body = build_body(messages, model, max_tokens, system, tools)

      case do_stream_request(api_url, api_key, body, on_chunk) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Non-streaming message request. Returns the full response.
  """
  def send_message(messages, opts \\ []) do
    api_key = api_key()
    api_url = api_url()

    if is_nil(api_key) do
      {:error, "ANTHROPIC_API_KEY not configured"}
    else
      model = Keyword.get(opts, :model, @default_model)
      system = Keyword.get(opts, :system)
      max_tokens = Keyword.get(opts, :max_tokens, 4096)

      body = build_body(messages, model, max_tokens, system) |> Map.delete(:stream)

      case Req.post("#{api_url}/v1/messages",
             json: body,
             headers: headers(api_key),
             receive_timeout: 120_000
           ) do
        {:ok, %{status: 200, body: resp}} ->
          content = extract_content(resp)
          usage = extract_usage(resp)
          {:ok, %{content: content, usage: usage}}

        {:ok, %{status: status, body: resp}} ->
          {:error, "API returned #{status}: #{inspect(resp)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  # --- Private ---

  defp build_body(messages, model, max_tokens, system, tools \\ nil) do
    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: messages,
      stream: true
    }

    body = if system, do: Map.put(body, :system, system), else: body
    body = if tools && tools != [], do: Map.put(body, :tools, tools), else: body
    body
  end

  defp do_stream_request(api_url, api_key, body, on_chunk) do
    # Use Req with into: :self for streaming
    parent = self()
    ref = make_ref()

    task =
      Task.async(fn ->
        # content_blocks accumulates structured blocks (text and tool_use)
        # current_block tracks the block being assembled
        acc = %{
          content: "",
          usage: %{},
          buffer: "",
          stop_reason: nil,
          content_blocks: [],
          current_block: nil
        }

        case Req.post("#{api_url}/v1/messages",
               json: body,
               headers: headers(api_key),
               receive_timeout: 120_000,
               into: :self
             ) do
          {:ok, resp} ->
            final = consume_stream(resp, acc, on_chunk)
            send(parent, {ref, {:ok, final}})

          {:error, reason} ->
            send(parent, {ref, {:error, reason}})
        end
      end)

    receive do
      {^ref, result} ->
        Task.shutdown(task, :brutal_kill)
        result
    after
      180_000 ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  end

  defp consume_stream(resp, acc, on_chunk) do
    receive do
      {_, ^resp, {:data, data}} ->
        {events, new_buffer} = parse_sse(acc.buffer <> data)
        new_acc = process_events(events, %{acc | buffer: new_buffer}, on_chunk)
        consume_stream(resp, new_acc, on_chunk)

      {_, ^resp, :done} ->
        finalize_result(acc)

      {_, ^resp, {:error, _reason}} ->
        finalize_result(acc)
    after
      120_000 ->
        finalize_result(acc)
    end
  end

  # If any tool_use blocks were assembled, return them as structured content list.
  # Otherwise return the plain text string for backwards compatibility with ChatAgent.
  defp finalize_result(acc) do
    has_tool_use = Enum.any?(acc.content_blocks, fn b -> Map.get(b, "type") == "tool_use" end)

    content =
      if has_tool_use do
        acc.content_blocks
      else
        acc.content
      end

    %{content: content, usage: acc.usage, stop_reason: acc.stop_reason}
  end

  defp process_events(events, acc, on_chunk) do
    Enum.reduce(events, acc, fn event, a ->
      case event do
        # Track the start of a new content block
        %{"type" => "content_block_start", "index" => _idx, "content_block" => block} ->
          %{a | current_block: block}

        # Text delta — accumulate both in content string and current block
        %{"type" => "content_block_delta", "delta" => %{"type" => "text_delta", "text" => text}} ->
          on_chunk.(text)
          updated_block =
            case a.current_block do
              %{"type" => "text"} = b -> Map.update(b, "text", text, &(&1 <> text))
              other -> other
            end
          %{a | content: a.content <> text, current_block: updated_block}

        # Backwards-compat: plain text delta without type field
        %{"type" => "content_block_delta", "delta" => %{"text" => text}} ->
          on_chunk.(text)
          %{a | content: a.content <> text}

        # Tool use input JSON delta — accumulate JSON string into current block
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "input_json_delta", "partial_json" => partial}
        } ->
          updated_block =
            case a.current_block do
              %{"type" => "tool_use"} = b ->
                Map.update(b, "_input_json", partial, &(&1 <> partial))

              other ->
                other
            end
          %{a | current_block: updated_block}

        # End of a content block — finalize and store it
        %{"type" => "content_block_stop"} ->
          finalized_block = finalize_block(a.current_block)

          blocks =
            if finalized_block, do: a.content_blocks ++ [finalized_block], else: a.content_blocks

          %{a | content_blocks: blocks, current_block: nil}

        %{"type" => "message_delta", "usage" => usage} = evt ->
          stop = Map.get(evt, "delta") |> then(fn d -> if is_map(d), do: Map.get(d, "stop_reason"), else: nil end)
          %{a | usage: Map.merge(a.usage, normalize_usage(usage)), stop_reason: stop || a.stop_reason}

        %{"type" => "message_start", "message" => %{"usage" => usage}} ->
          %{a | usage: Map.merge(a.usage, normalize_usage(usage))}

        _ ->
          a
      end
    end)
  end

  # Parse accumulated JSON for tool_use blocks; keep text blocks as-is.
  defp finalize_block(nil), do: nil

  defp finalize_block(%{"type" => "tool_use"} = block) do
    input_json = Map.get(block, "_input_json", "{}")

    input =
      case Jason.decode(input_json) do
        {:ok, parsed} -> parsed
        _ -> %{}
      end

    block
    |> Map.delete("_input_json")
    |> Map.put("input", input)
  end

  defp finalize_block(block), do: block

  defp parse_sse(data) do
    parts = String.split(data, "\n\n")

    case parts do
      [single] ->
        # No complete event yet, buffer everything
        {[], single}

      parts ->
        {complete, [remainder]} = Enum.split(parts, -1)

        events =
          complete
          |> Enum.map(&parse_sse_event/1)
          |> Enum.reject(&is_nil/1)

        {events, remainder}
    end
  end

  defp parse_sse_event(raw) do
    raw
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        ["data", json_str] ->
          case Jason.decode(json_str) do
            {:ok, parsed} -> Map.merge(acc, parsed)
            _ -> acc
          end

        ["event", _event_name] ->
          acc

        _ ->
          acc
      end
    end)
    |> case do
      empty when map_size(empty) == 0 -> nil
      event -> event
    end
  end

  defp extract_content(%{"content" => [%{"text" => text} | _]}), do: text
  defp extract_content(_), do: ""

  defp extract_usage(%{"usage" => usage}), do: normalize_usage(usage)
  defp extract_usage(_), do: %{}

  defp normalize_usage(usage) when is_map(usage) do
    %{
      input_tokens: usage["input_tokens"] || 0,
      output_tokens: usage["output_tokens"] || 0
    }
  end

  defp normalize_usage(_), do: %{}

  defp headers(api_key) do
    [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"}
    ]
  end

  defp api_key, do: Application.get_env(:james, :anthropic_api_key) || System.get_env("ANTHROPIC_API_KEY")
  defp api_url, do: System.get_env("ANTHROPIC_API_URL", @default_url)
end
