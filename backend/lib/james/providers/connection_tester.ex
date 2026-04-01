defmodule James.Providers.ConnectionTester do
  @moduledoc """
  Tests connectivity to LLM provider endpoints.

  Dispatches by `provider_type` on a `ProviderConfig` struct.

  - Cloud providers (anthropic, openai, gemini, minimax, openai_codex): sends
    a minimal 1-token completion request and measures round-trip latency.
  - Local providers (ollama, lm_studio, openai_compatible): sends a `GET /`
    request to the `base_url` to confirm the server is reachable.

  Returns `{:ok, %{status: :connected, latency_ms: non_neg_integer()}}` on
  success, or `{:error, %{status: :failed, reason: String.t()}}` on failure.
  """

  alias James.Providers.ProviderConfig

  @cloud_providers ~w(anthropic openai openai_codex gemini minimax)
  @local_providers ~w(ollama lm_studio openai_compatible)

  @doc """
  Tests the connection for the given `ProviderConfig`.

  Returns:
    - `{:ok, %{status: :connected, latency_ms: integer()}}` on success
    - `{:error, %{status: :failed, reason: String.t()}}` on failure
  """
  @spec test_connection(ProviderConfig.t()) ::
          {:ok, %{status: :connected, latency_ms: non_neg_integer()}}
          | {:error, %{status: :failed, reason: String.t()}}
  def test_connection(%ProviderConfig{provider_type: type} = config)
      when type in @cloud_providers do
    test_cloud(config)
  end

  def test_connection(%ProviderConfig{provider_type: type} = config)
      when type in @local_providers do
    test_local(config)
  end

  def test_connection(%ProviderConfig{provider_type: type}) do
    {:error, %{status: :failed, reason: "unsupported_provider_type:#{type}"}}
  end

  # ---------------------------------------------------------------------------
  # Cloud providers — send a minimal 1-token completion request
  # ---------------------------------------------------------------------------

  defp test_cloud(%ProviderConfig{provider_type: "anthropic"} = config) do
    api_key = config.decrypted_api_key
    base_url = config.base_url || "https://api.anthropic.com"

    body =
      Jason.encode!(%{
        model: "claude-haiku-20240307",
        max_tokens: 1,
        messages: [%{role: "user", content: "hi"}]
      })

    headers = [
      {"x-api-key", api_key || ""},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    measure(fn ->
      Req.post("#{base_url}/v1/messages",
        body: body,
        headers: headers,
        receive_timeout: 10_000
      )
    end)
    |> interpret_cloud_response()
  end

  defp test_cloud(%ProviderConfig{provider_type: type} = config)
       when type in ~w(openai openai_codex openai_compatible) do
    api_key = config.decrypted_api_key
    base_url = config.base_url || "https://api.openai.com"

    body =
      Jason.encode!(%{
        model: "gpt-4o-mini",
        max_tokens: 1,
        messages: [%{role: "user", content: "hi"}]
      })

    headers = [
      {"authorization", "Bearer #{api_key || ""}"},
      {"content-type", "application/json"}
    ]

    measure(fn ->
      Req.post("#{base_url}/v1/chat/completions",
        body: body,
        headers: headers,
        receive_timeout: 10_000
      )
    end)
    |> interpret_cloud_response()
  end

  defp test_cloud(%ProviderConfig{provider_type: "gemini"} = config) do
    api_key = config.decrypted_api_key
    base_url = config.base_url || "https://generativelanguage.googleapis.com"

    body =
      Jason.encode!(%{
        contents: [%{parts: [%{text: "hi"}]}],
        generationConfig: %{maxOutputTokens: 1}
      })

    headers = [{"content-type", "application/json"}]
    url = "#{base_url}/v1beta/models/gemini-2.0-flash:generateContent?key=#{api_key || ""}"

    measure(fn ->
      Req.post(url,
        body: body,
        headers: headers,
        receive_timeout: 10_000
      )
    end)
    |> interpret_cloud_response()
  end

  defp test_cloud(%ProviderConfig{provider_type: "minimax"} = config) do
    # MiniMax offers an Anthropic-compatible API at https://api.minimax.io/anthropic
    api_key = config.decrypted_api_key
    base_url = config.base_url || "https://api.minimax.io/anthropic"

    body =
      Jason.encode!(%{
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1,
        messages: [%{role: "user", content: "hi"}]
      })

    headers = [
      {"x-api-key", api_key || ""},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    measure(fn ->
      Req.post("#{base_url}/v1/messages",
        body: body,
        headers: headers,
        receive_timeout: 10_000
      )
    end)
    |> interpret_cloud_response()
  end

  # ---------------------------------------------------------------------------
  # Local providers — GET / on the base_url
  # ---------------------------------------------------------------------------

  defp test_local(%ProviderConfig{base_url: nil}) do
    {:error, %{status: :failed, reason: "network_error"}}
  end

  defp test_local(%ProviderConfig{base_url: base_url}) do
    measure(fn ->
      Req.get("#{base_url}/",
        receive_timeout: 5_000
      )
    end)
    |> interpret_local_response()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Runs `fun` and returns `{elapsed_ms, result}`.
  defp measure(fun) do
    start = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = System.monotonic_time(:millisecond) - start
    {elapsed, result}
  end

  defp interpret_cloud_response({elapsed, {:ok, %{status: 200}}}) do
    {:ok, %{status: :connected, latency_ms: elapsed}}
  end

  defp interpret_cloud_response({elapsed, {:ok, %{status: status}}})
       when status in [200, 201, 400] do
    # 400 means the key is valid enough to reach the API; treat as connected
    {:ok, %{status: :connected, latency_ms: elapsed}}
  end

  defp interpret_cloud_response({_elapsed, {:ok, %{status: 401}}}) do
    {:error, %{status: :failed, reason: "invalid_api_key"}}
  end

  defp interpret_cloud_response({_elapsed, {:ok, %{status: 429}}}) do
    {:error, %{status: :failed, reason: "rate_limited"}}
  end

  defp interpret_cloud_response({_elapsed, {:ok, %{status: status}}}) do
    {:error, %{status: :failed, reason: "http_#{status}"}}
  end

  defp interpret_cloud_response({_elapsed, {:error, _reason}}) do
    {:error, %{status: :failed, reason: "network_error"}}
  end

  defp interpret_local_response({elapsed, {:ok, %{status: _status}}}) do
    {:ok, %{status: :connected, latency_ms: elapsed}}
  end

  defp interpret_local_response({_elapsed, {:error, _reason}}) do
    {:error, %{status: :failed, reason: "network_error"}}
  end
end
