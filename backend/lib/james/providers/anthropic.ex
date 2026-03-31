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
    - `:on_chunk` — `fn chunk_text -> :ok end` called for each content delta
    - `:on_done` — `fn usage_map -> :ok end` called when stream completes

  Returns `{:ok, %{content: String.t(), usage: map()}}` or `{:error, reason}`.
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
      on_chunk = Keyword.get(opts, :on_chunk, fn _ -> :ok end)

      body = build_body(messages, model, max_tokens, system)

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

  defp build_body(messages, model, max_tokens, system) do
    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: messages,
      stream: true
    }

    if system, do: Map.put(body, :system, system), else: body
  end

  defp do_stream_request(api_url, api_key, body, on_chunk) do
    # Use Req with into: :self for streaming
    parent = self()
    ref = make_ref()

    task =
      Task.async(fn ->
        acc = %{content: "", usage: %{}, buffer: ""}

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
        %{content: acc.content, usage: acc.usage}

      {_, ^resp, {:error, _reason}} ->
        %{content: acc.content, usage: acc.usage}
    after
      120_000 ->
        %{content: acc.content, usage: acc.usage}
    end
  end

  defp process_events(events, acc, on_chunk) do
    Enum.reduce(events, acc, fn event, a ->
      case event do
        %{"type" => "content_block_delta", "delta" => %{"text" => text}} ->
          on_chunk.(text)
          %{a | content: a.content <> text}

        %{"type" => "message_delta", "usage" => usage} ->
          %{a | usage: Map.merge(a.usage, normalize_usage(usage))}

        %{"type" => "message_start", "message" => %{"usage" => usage}} ->
          %{a | usage: Map.merge(a.usage, normalize_usage(usage))}

        _ ->
          a
      end
    end)
  end

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
