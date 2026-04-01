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
  """

  @table :james_provider_registry

  @built_in_prefixes %{
    "claude" => James.Providers.Anthropic,
    "gpt" => James.Providers.OpenAI,
    "gemini" => James.Providers.Gemini
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

  # --- Private ---

  defp config_prefixes do
    Application.get_env(:james, :llm_provider_registry, %{})
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end
  end
end
