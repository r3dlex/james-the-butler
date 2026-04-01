defmodule James.Providers.ModelCatalog do
  @moduledoc """
  Provides a list of available models for each LLM provider.

  Cloud providers return a hardcoded list of known models; this avoids the need
  for an extra API round-trip just to populate a UI dropdown.

  Local providers (Ollama, LM Studio, OpenAI-compatible) dynamically query the
  running server to discover what models are loaded.
  """

  # ---------------------------------------------------------------------------
  # Hardcoded cloud models
  # ---------------------------------------------------------------------------

  @anthropic_models ~w(
    claude-opus-4-5
    claude-sonnet-4-5
    claude-haiku-4-5
    claude-opus-4-20250514
    claude-sonnet-4-20250514
    claude-haiku-4-20250514
    claude-3-5-sonnet-20241022
    claude-3-5-haiku-20241022
    claude-3-opus-20240229
    claude-3-haiku-20240307
  )

  @openai_models ~w(
    gpt-4o
    gpt-4o-mini
    gpt-4-turbo
    gpt-4
    gpt-3.5-turbo
    o1
    o1-mini
    o3
    o3-mini
    o4-mini
  )

  @gemini_models ~w(
    gemini-2.5-pro
    gemini-2.5-flash
    gemini-2.0-flash
    gemini-2.0-flash-lite
    gemini-1.5-pro
    gemini-1.5-flash
    gemini-1.0-pro
  )

  @minimax_models ~w(
    abab6.5s-chat
    abab6.5t-chat
    abab6-chat
    abab5.5s-chat
    abab5.5-chat
  )

  @doc """
  Returns a hardcoded list of known model identifiers for a cloud provider.

  Accepts: `"anthropic"`, `"openai"`, `"openai_codex"`, `"gemini"`, `"minimax"`.

  Returns `{:ok, [String.t()]}` on success or `{:error, String.t()}` for an
  unknown provider name.
  """
  @spec list_models(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_models("anthropic"), do: {:ok, @anthropic_models}
  def list_models("openai"), do: {:ok, @openai_models}
  def list_models("openai_codex"), do: {:ok, @openai_models}
  def list_models("gemini"), do: {:ok, @gemini_models}
  def list_models("minimax"), do: {:ok, @minimax_models}

  def list_models(provider) do
    {:error, "unknown_provider:#{provider}"}
  end

  @doc """
  Queries a running local LLM server for its available models.

  - `"ollama"` — calls `GET /api/tags` and extracts model names from the
    `models[].name` field.
  - `"lm_studio"` / `"openai_compatible"` — calls `GET /v1/models` and
    extracts model IDs from the `data[].id` field (OpenAI models API format).

  Returns `{:ok, [String.t()]}` on success or `{:error, String.t()}` when the
  endpoint is unreachable or returns an unexpected response.
  """
  @spec list_models(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_models("ollama", base_url) do
    case Req.get("#{base_url}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        models =
          body
          |> Map.get("models", [])
          |> Enum.map(& &1["name"])
          |> Enum.reject(&is_nil/1)

        {:ok, models}

      {:ok, %{status: status}} ->
        {:error, "unexpected_status:#{status}"}

      {:error, _reason} ->
        {:error, "network_error"}
    end
  end

  def list_models(provider, base_url) when provider in ~w(lm_studio openai_compatible) do
    case Req.get("#{base_url}/v1/models", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        models =
          body
          |> Map.get("data", [])
          |> Enum.map(& &1["id"])
          |> Enum.reject(&is_nil/1)

        {:ok, models}

      {:ok, %{status: status}} ->
        {:error, "unexpected_status:#{status}"}

      {:error, _reason} ->
        {:error, "network_error"}
    end
  end

  def list_models(provider, _base_url) do
    {:error, "unknown_provider:#{provider}"}
  end
end
