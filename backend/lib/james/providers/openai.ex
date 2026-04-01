defmodule James.Providers.OpenAI do
  @moduledoc """
  HTTP client for the OpenAI Chat Completions API (and any OpenAI-compatible endpoint
  such as Ollama, Azure OpenAI, or local LLMs).

  Supports both streaming and non-streaming requests using the same message format as
  `James.Providers.Anthropic` for easy provider swapping.
  """

  @default_model "gpt-4o"
  @default_url "https://api.openai.com"

  @doc """
  Sends a streaming chat completion request.

  Options:
    - `:model` — model identifier (default: gpt-4o)
    - `:system` — system prompt string
    - `:max_tokens` — max response tokens (default: 4096)
    - `:on_chunk` — `fn chunk_text -> :ok end` called for each content delta
    - `:base_url` — override the API base URL (e.g. for Ollama: "http://localhost:11434")

  Returns `{:ok, %{content: String.t(), usage: map()}}` or `{:error, reason}`.
  """
  def stream_message(messages, opts \\ []) do
    api_key = api_key()
    base_url = Keyword.get(opts, :base_url, api_url())

    if is_nil(api_key) do
      {:error, "OPENAI_API_KEY not configured"}
    else
      model = Keyword.get(opts, :model, @default_model)
      system = Keyword.get(opts, :system)
      max_tokens = Keyword.get(opts, :max_tokens, 4096)
      on_chunk = Keyword.get(opts, :on_chunk, fn _ -> :ok end)

      body = build_body(messages, model, max_tokens, system, stream: true)
      do_stream_request(base_url, api_key, body, on_chunk)
    end
  end

  @doc """
  Non-streaming chat completion request. Returns the full response.
  """
  def send_message(messages, opts \\ []) do
    api_key = api_key()
    base_url = Keyword.get(opts, :base_url, api_url())

    if is_nil(api_key) do
      {:error, "OPENAI_API_KEY not configured"}
    else
      model = Keyword.get(opts, :model, @default_model)
      system = Keyword.get(opts, :system)
      max_tokens = Keyword.get(opts, :max_tokens, 4096)

      body = build_body(messages, model, max_tokens, system, stream: false)

      case Req.post("#{base_url}/v1/chat/completions",
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

  defp build_body(messages, model, max_tokens, system, extra_opts) do
    openai_messages =
      if system do
        [%{role: "system", content: system} | messages]
      else
        messages
      end

    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: openai_messages
    }

    if Keyword.get(extra_opts, :stream, false) do
      Map.put(body, :stream, true)
    else
      body
    end
  end

  defp do_stream_request(base_url, api_key, body, on_chunk) do
    parent = self()
    ref = make_ref()

    task =
      Task.async(fn ->
        acc = %{content: "", usage: %{}, buffer: ""}

        case Req.post("#{base_url}/v1/chat/completions",
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
    Enum.reduce(events, acc, fn event, a -> process_event(event, a, on_chunk) end)
  end

  defp process_event(%{"choices" => [%{"delta" => %{"content" => text}} | _]}, a, on_chunk)
       when is_binary(text) do
    on_chunk.(text)
    %{a | content: a.content <> text}
  end

  defp process_event(%{"usage" => usage}, a, _on_chunk) when is_map(usage) do
    %{a | usage: normalize_usage(usage)}
  end

  defp process_event(_event, a, _on_chunk), do: a

  defp parse_sse(data) do
    parts = String.split(data, "\n\n")

    case parts do
      [single] ->
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
    |> Enum.reduce(%{}, fn line, acc -> parse_sse_line(line, acc) end)
    |> case do
      empty when map_size(empty) == 0 -> nil
      event -> event
    end
  end

  defp parse_sse_line(line, acc) do
    case String.split(line, ": ", parts: 2) do
      ["data", "[DONE]"] ->
        acc

      ["data", json_str] ->
        case Jason.decode(json_str) do
          {:ok, parsed} -> Map.merge(acc, parsed)
          _ -> acc
        end

      _ ->
        acc
    end
  end

  defp extract_content(%{"choices" => [%{"message" => %{"content" => text}} | _]}), do: text
  defp extract_content(_), do: ""

  defp extract_usage(%{"usage" => usage}), do: normalize_usage(usage)
  defp extract_usage(_), do: %{}

  defp normalize_usage(usage) when is_map(usage) do
    %{
      input_tokens: usage["prompt_tokens"] || 0,
      output_tokens: usage["completion_tokens"] || 0
    }
  end

  defp normalize_usage(_), do: %{}

  defp headers(api_key), do: [{"Authorization", "Bearer #{api_key}"}]

  defp api_key,
    do: Application.get_env(:james, :openai_api_key) || System.get_env("OPENAI_API_KEY")

  defp api_url, do: System.get_env("OPENAI_API_URL", @default_url)
end
