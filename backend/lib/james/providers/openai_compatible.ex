defmodule James.Providers.OpenAICompatible do
  @moduledoc """
  OpenAI-compatible generic provider.

  Delegates all requests to `James.Providers.OpenAI` with a configurable
  `base_url`, making it easy to connect to local LLM servers such as
  Ollama (`http://localhost:11434`) or LM Studio (any custom URL).

  ## Options

    - `:base_url` — base URL for the API endpoint (required)
    - `:api_key` — API key to use (optional; overrides env/app config)
    - `:no_auth` — when `true`, skips API-key requirement and sends
      a placeholder bearer token so OpenAI provider doesn't reject the
      request before it reaches the network
    - Any option accepted by `James.Providers.OpenAI`

  ## Examples

      # Ollama (no API key needed)
      OpenAICompatible.send_message(messages,
        base_url: "http://localhost:11434",
        no_auth: true,
        model: "llama3"
      )

      # LM Studio
      OpenAICompatible.send_message(messages,
        base_url: "http://localhost:1234",
        no_auth: true,
        model: "local-model"
      )
  """

  @behaviour James.LLMProvider

  alias James.Providers.OpenAI

  @doc """
  Delegates a non-streaming request to `James.Providers.OpenAI` with a
  custom `:base_url`.  Pass `no_auth: true` for endpoints that don't
  require an API key (e.g. Ollama, LM Studio).
  """
  @impl James.LLMProvider
  def send_message(messages, opts \\ []) do
    OpenAI.send_message(messages, prepare_opts(opts))
  end

  @doc """
  Delegates a streaming request to `James.Providers.OpenAI` with a
  custom `:base_url`.  Pass `no_auth: true` for endpoints that don't
  require an API key.
  """
  @impl James.LLMProvider
  def stream_message(messages, opts \\ []) do
    OpenAI.stream_message(messages, prepare_opts(opts))
  end

  # --- Private ---

  # Build the opts list that OpenAI provider will accept:
  #  - inject a placeholder API key via app env when no_auth: true
  #  - honour an explicit :api_key opt by writing it into app env temporarily
  defp prepare_opts(opts) do
    {no_auth, opts} = Keyword.pop(opts, :no_auth, false)
    {api_key, opts} = Keyword.pop(opts, :api_key, nil)

    cond do
      api_key ->
        # Override the env so OpenAI's api_key/0 picks it up
        Application.put_env(:james, :openai_api_key, api_key)
        opts

      no_auth ->
        # Inject a placeholder so the OpenAI provider doesn't short-circuit
        Application.put_env(:james, :openai_api_key, "no-auth")
        opts

      true ->
        opts
    end
  end
end
