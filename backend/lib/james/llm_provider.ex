defmodule James.LLMProvider do
  @moduledoc """
  Behaviour for LLM providers. Allows swapping the provider at runtime,
  which enables clean unit testing via mock injection.

  Configure the provider in config:
    config :james, :llm_provider, James.Providers.Anthropic
  """

  @doc """
  Sends a streaming message request. Returns
  `{:ok, %{content: ..., usage: ..., stop_reason: ...}}` or `{:error, reason}`.
  """
  @callback stream_message(messages :: list(), opts :: keyword()) ::
              {:ok, %{content: term(), usage: map(), stop_reason: term()}}
              | {:error, term()}

  @doc """
  Sends a non-streaming message request. Returns
  `{:ok, %{content: String.t(), usage: map()}}` or `{:error, reason}`.
  """
  @callback send_message(messages :: list(), opts :: keyword()) ::
              {:ok, %{content: String.t(), usage: map()}} | {:error, term()}

  @doc """
  Returns the configured LLM provider module.
  Defaults to `James.Providers.Anthropic` if not configured.
  """
  def configured do
    Application.fetch_env!(:james, :llm_provider)
  end
end
