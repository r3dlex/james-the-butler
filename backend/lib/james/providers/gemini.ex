defmodule James.Providers.Gemini do
  @moduledoc """
  HTTP client for the Google Gemini API (Generative Language API).

  Implements both streaming and non-streaming requests using the same message
  format as `James.Providers.Anthropic` and `James.Providers.OpenAI` for easy
  provider swapping.

  The API key is passed as a `?key=` query parameter per Google's convention.
  System prompts are sent as `system_instruction` rather than a message in
  `contents`, as required by the Gemini API.
  """

  @behaviour James.LLMProvider

  @default_model "gemini-2.0-flash"
  @default_url "https://generativelanguage.googleapis.com"

  @doc """
  Sends a streaming content generation request to the Gemini API.

  Options:
    - `:model` — model identifier (default: gemini-2.0-flash)
    - `:system` — system prompt string (sent as `system_instruction`)
    - `:max_tokens` — max response tokens (default: 4096)
    - `:on_chunk` — `fn chunk_text -> :ok end` called for each content delta

  Returns `{:ok, %{content: String.t(), usage: map()}}` or `{:error, reason}`.
  """
  @impl James.LLMProvider
  def stream_message(messages, opts \\ []) do
    api_key = api_key()

    if is_nil(api_key) do
      {:error, "GOOGLE_API_KEY not configured"}
    else
      model = Keyword.get(opts, :model, @default_model)
      system = Keyword.get(opts, :system)
      max_tokens = Keyword.get(opts, :max_tokens, 4096)
      on_chunk = Keyword.get(opts, :on_chunk, fn _ -> :ok end)
      base_url = api_url()

      body = build_body(messages, max_tokens, system)
      url = "#{base_url}/v1beta/models/#{model}:streamGenerateContent"
      do_stream_request(url, api_key, body, on_chunk)
    end
  end

  @doc """
  Non-streaming content generation request. Returns the full response.
  """
  @impl James.LLMProvider
  def send_message(messages, opts \\ []) do
    api_key = api_key()

    if is_nil(api_key) do
      {:error, "GOOGLE_API_KEY not configured"}
    else
      model = Keyword.get(opts, :model, @default_model)
      system = Keyword.get(opts, :system)
      max_tokens = Keyword.get(opts, :max_tokens, 4096)
      base_url = api_url()

      body = build_body(messages, max_tokens, system)
      url = "#{base_url}/v1beta/models/#{model}:generateContent"

      case Req.post(url,
             json: body,
             params: [key: api_key],
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

  defp build_body(messages, max_tokens, system) do
    contents = Enum.map(messages, &to_gemini_message/1)

    body = %{
      contents: contents,
      generationConfig: %{maxOutputTokens: max_tokens}
    }

    if system do
      Map.put(body, :system_instruction, %{parts: [%{text: system}]})
    else
      body
    end
  end

  defp to_gemini_message(%{role: role, content: content}) do
    %{role: role, parts: [%{text: content}]}
  end

  defp to_gemini_message(%{"role" => role, "content" => content}) do
    %{role: role, parts: [%{text: content}]}
  end

  defp do_stream_request(url, api_key, body, on_chunk) do
    parent = self()
    ref = make_ref()

    task =
      Task.async(fn ->
        acc = %{content: "", usage: %{}, buffer: ""}

        case Req.post(url,
               json: body,
               params: [key: api_key, alt: "sse"],
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

  defp process_event(
         %{"candidates" => [%{"content" => %{"parts" => parts}} | _]} = event,
         acc,
         on_chunk
       ) do
    text = Enum.map_join(parts, fn p -> Map.get(p, "text", "") end)

    on_chunk.(text)

    usage =
      case Map.get(event, "usageMetadata") do
        nil -> acc.usage
        meta -> normalize_usage(meta)
      end

    %{acc | content: acc.content <> text, usage: usage}
  end

  defp process_event(%{"usageMetadata" => meta}, acc, _on_chunk) when is_map(meta) do
    %{acc | usage: normalize_usage(meta)}
  end

  defp process_event(_event, acc, _on_chunk), do: acc

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
      ["data", json_str] ->
        case Jason.decode(json_str) do
          {:ok, parsed} -> Map.merge(acc, parsed)
          _ -> acc
        end

      _ ->
        acc
    end
  end

  defp extract_content(%{
         "candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _]
       }),
       do: text

  defp extract_content(_), do: ""

  defp extract_usage(%{"usageMetadata" => meta}), do: normalize_usage(meta)
  defp extract_usage(_), do: %{}

  defp normalize_usage(meta) when is_map(meta) do
    %{
      input_tokens: meta["promptTokenCount"] || 0,
      output_tokens: meta["candidatesTokenCount"] || 0
    }
  end

  defp normalize_usage(_), do: %{}

  defp api_key,
    do: Application.get_env(:james, :google_api_key) || System.get_env("GOOGLE_API_KEY")

  defp api_url, do: System.get_env("GEMINI_API_URL", @default_url)
end
