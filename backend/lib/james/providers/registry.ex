defmodule James.Providers.Registry do
  @moduledoc """
  Maps model name prefixes to LLM provider modules.

  Built-in prefix mappings:
    - "claude" → `James.Providers.Anthropic`
    - "gpt" → `James.Providers.OpenAI`
    - "gemini" → `James.Providers.Gemini`

  Custom prefix → provider mappings can be added at runtime via
  `register_custom/2`, which stores entries in an ETS table.
  Additional built-ins may also be supplied via application config:

      config :james, :llm_provider_registry, %{"my-prefix" => MyApp.Provider}

  ## Session-level resolution

  `provider_for_session/2` looks up the DB-configured model default for a
  session's (user, host, agent_type) tuple and returns the resolved provider
  module + model name. Falls back to the global `LLMProvider.configured/0`
  when no DB config exists.

  `resolve_provider/1` is a convenience wrapper that returns
  `{provider_module, model_name, opts}`.
  """

  alias James.LLMProvider
  alias James.ProviderSettings

  @table :james_provider_registry

  @built_in_prefixes %{
    "claude" => James.Providers.Anthropic,
    "gpt" => James.Providers.OpenAI,
    "gemini" => James.Providers.Gemini,
    "MiniMax" => James.Providers.Anthropic
  }

  # Maps provider_type string → provider module atom
  @provider_type_map %{
    "anthropic" => James.Providers.Anthropic,
    "openai" => James.Providers.OpenAI,
    "openai_codex" => James.Providers.OpenAI,
    "gemini" => James.Providers.Gemini,
    "ollama" => James.Providers.OpenAICompatible,
    "lm_studio" => James.Providers.OpenAICompatible,
    "openai_compatible" => James.Providers.OpenAICompatible,
    "minimax" => James.Providers.Anthropic
  }

  @doc """
  Looks up the provider module for the given `model` name.

  Returns `{:ok, module}` when a matching prefix is found, or
  `{:error, :unknown_provider}` when no prefix matches.
  """
  @spec provider_for_model(String.t()) :: {:ok, module()} | {:error, :unknown_provider}
  def provider_for_model(model) when is_binary(model) do
    all_prefixes = Map.merge(@built_in_prefixes, config_prefixes())

    custom_prefixes =
      case :ets.whereis(@table) do
        :undefined ->
          %{}

        _tid ->
          @table
          |> :ets.tab2list()
          |> Map.new(fn {prefix, mod} -> {prefix, mod} end)
      end

    merged = Map.merge(all_prefixes, custom_prefixes)

    result =
      Enum.find(merged, fn {prefix, _mod} ->
        String.starts_with?(model, prefix)
      end)

    case result do
      {_prefix, mod} -> {:ok, mod}
      nil -> {:error, :unknown_provider}
    end
  end

  @doc """
  Returns all registered provider modules (built-in + config + custom).

  The list contains unique module atoms; order is not guaranteed.
  """
  @spec list_providers() :: [module()]
  def list_providers do
    all_prefixes = Map.merge(@built_in_prefixes, config_prefixes())

    custom_prefixes =
      case :ets.whereis(@table) do
        :undefined ->
          %{}

        _tid ->
          @table
          |> :ets.tab2list()
          |> Map.new(fn {prefix, mod} -> {prefix, mod} end)
      end

    all_prefixes
    |> Map.merge(custom_prefixes)
    |> Map.values()
    |> Enum.uniq()
  end

  @doc """
  Registers a custom `prefix` → `provider` mapping at runtime.

  The mapping is stored in an ETS table and takes precedence over
  built-in and config-based mappings. Returns `:ok`.

  ## Examples

      iex> James.Providers.Registry.register_custom("my-llm", MyApp.LLMProvider)
      :ok
  """
  @spec register_custom(String.t(), module()) :: :ok
  def register_custom(prefix, provider) when is_binary(prefix) and is_atom(provider) do
    ensure_table()
    :ets.insert(@table, {prefix, provider})
    :ok
  end

  @doc """
  Resolves the provider module and model name for a session + agent_type pair.

  Resolution order:
  1. Session metadata `:model_override` (if present).
  2. DB model default for (session.user_id, session.host_id, agent_type) →
     looks up the referenced `ProviderConfig` and maps `provider_type` to a
     module.
  3. Global fallback: `{LLMProvider.configured(), nil}`.

  Returns:
  - `{:ok, %{module: provider_module, model: model_name_or_nil}}` on success.
  - `{:error, :provider_config_not_found}` when a model default references a
    non-existent provider config.
  """
  @spec provider_for_session(map(), String.t()) ::
          {:ok, %{module: module(), model: String.t() | nil}}
          | {:error, :provider_config_not_found}
  def provider_for_session(session, agent_type) do
    # 1. Session-level model override in metadata
    model_override =
      case Map.get(session, :metadata) do
        %{"model_override" => m} when is_binary(m) -> m
        _ -> nil
      end

    if model_override do
      resolve_from_model_name(model_override)
    else
      resolve_from_db(session, agent_type)
    end
  end

  @doc """
  Convenience wrapper around `provider_for_session/2`.

  Returns `{provider_module, model_name, opts}` where `opts` is an empty list
  by default (callers may extend it). Falls back to global config when no DB
  entry is found.
  """
  @spec resolve_provider(map()) :: {module(), String.t() | nil, keyword()}
  def resolve_provider(session) do
    agent_type = Map.get(session, :agent_type, "chat")

    case provider_for_session(session, agent_type) do
      {:ok, %{module: mod, model: model, opts: opts}} -> {mod, model, opts}
      {:ok, %{module: mod, model: model}} -> {mod, model, []}
      {:error, _} -> {LLMProvider.configured(), nil, []}
    end
  end

  # --- Private ---

  defp config_prefixes do
    Application.get_env(:james, :llm_provider_registry, %{})
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end
  end

  # Resolve provider from a model name string using prefix matching.
  defp resolve_from_model_name(model_name) do
    case provider_for_model(model_name) do
      {:ok, mod} ->
        {:ok, %{module: mod, model: model_name, opts: []}}

      {:error, :unknown_provider} ->
        {:ok, %{module: LLMProvider.configured(), model: model_name, opts: []}}
    end
  end

  # Look up model default from DB and map to provider module.
  defp resolve_from_db(session, agent_type) do
    user_id = Map.get(session, :user_id)
    host_id = Map.get(session, :host_id)

    case ProviderSettings.default_model_for(user_id, host_id, agent_type) do
      nil ->
        # No model default — try the user's first available provider config.
        resolve_from_user_config(user_id)

      %{model_name: model_name, provider_config_id: config_id} ->
        resolve_from_provider_config(config_id, model_name)
    end
  end

  # Fall back to the user's first connected (or any) provider config.
  # We use the globally configured provider module so that test environments
  # continue to use the mock; the api_key (and optional base_url) are injected
  # as opts so the caller authenticates with the user's DB credentials.
  defp resolve_from_user_config(nil) do
    {:ok, %{module: LLMProvider.configured(), model: nil, opts: []}}
  end

  defp resolve_from_user_config(user_id) do
    case ProviderSettings.first_provider_config_for_user(user_id) do
      nil ->
        {:ok, %{module: LLMProvider.configured(), model: nil, opts: []}}

      config ->
        opts =
          []
          |> maybe_put(:api_key, config.decrypted_api_key)
          |> maybe_put(:base_url, config.base_url)

        {:ok, %{module: LLMProvider.configured(), model: nil, opts: opts}}
    end
  end

  # Fetch ProviderConfig and map provider_type → module, returning credentials as opts.
  defp resolve_from_provider_config(config_id, model_name) do
    case ProviderSettings.get_provider_config(config_id) do
      nil ->
        {:error, :provider_config_not_found}

      config ->
        mod = Map.get(@provider_type_map, config.provider_type, LLMProvider.configured())

        opts =
          []
          |> maybe_put(:api_key, config.decrypted_api_key)
          |> maybe_put(:base_url, config.base_url)

        {:ok, %{module: mod, model: model_name, opts: opts}}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
