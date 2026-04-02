defmodule James.Providers.ProviderOAuth do
  @moduledoc """
  Manages OAuth 2.0 PKCE flows for connecting LLM providers (e.g. OpenAI Codex).

  Flow:
    1. `start_flow/2`  — generates PKCE pair + state key, stores in ETS,
                         returns `{auth_url, state_key}` for the browser redirect.
    2. Browser visits the auth URL, user approves, provider redirects back
       to `/api/providers/oauth/callback?code=…&state=…`.
    3. `handle_callback/2` — exchanges the code for tokens, persists the
       provider config, marks the state entry as :completed.
    4. Frontend polls `get_status/1` every few seconds until :completed.

  State entries expire automatically after @state_ttl_seconds.
  """

  use GenServer

  alias James.Accounts
  alias James.ProviderSettings

  @table :provider_oauth_states
  # 10 minutes
  @state_ttl_seconds 600

  # ---------------------------------------------------------------------------
  # Provider definitions
  # ---------------------------------------------------------------------------

  @provider_defs %{
    "openai_codex" => %{
      auth_url: "https://auth.openai.com/authorize",
      token_url: "https://auth.openai.com/oauth2/token",
      scopes: "openid profile email",
      client_id_env: "OPENAI_CODEX_CLIENT_ID",
      client_secret_env: "OPENAI_CODEX_CLIENT_SECRET"
    },
    "openai" => %{
      auth_url: "https://auth.openai.com/authorize",
      token_url: "https://auth.openai.com/oauth2/token",
      scopes: "openid profile email",
      client_id_env: "OPENAI_CLIENT_ID",
      client_secret_env: "OPENAI_CLIENT_SECRET"
    }
  }

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts an OAuth PKCE flow for the given provider type.

  Returns `{:ok, %{auth_url: url, state_key: key}}` or
  `{:error, reason}`.
  """
  def start_flow(provider_type, user_id) do
    GenServer.call(__MODULE__, {:start_flow, provider_type, user_id})
  end

  @doc """
  Handles the OAuth callback — exchanges the code, stores the provider config.
  Returns `{:ok, provider_config}` or `{:error, reason}`.
  """
  def handle_callback(code, state_key) do
    GenServer.call(__MODULE__, {:handle_callback, code, state_key}, 30_000)
  end

  @doc """
  Returns `{:ok, :pending}`, `{:ok, :completed, provider}`, or `{:error, reason}`.
  """
  def get_status(state_key) do
    case :ets.lookup(@table, state_key) do
      [{^state_key, entry}] ->
        case entry.status do
          :completed -> {:ok, :completed, entry[:provider]}
          _ -> {:ok, :pending}
        end

      [] ->
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table])
    # Periodically sweep expired entries
    :timer.send_interval(60_000, :sweep_expired)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:start_flow, provider_type, user_id}, _from, state) do
    case Map.fetch(runtime_provider_defs(), provider_type) do
      {:ok, def} ->
        {verifier, challenge} = generate_pkce()
        state_key = generate_state_key()
        redirect_uri = callback_uri()

        client_id = System.get_env(def.client_id_env)

        if is_nil(client_id) do
          {:reply, {:error, "#{def.client_id_env} environment variable not set"}, state}
        else
          params = %{
            client_id: client_id,
            redirect_uri: redirect_uri,
            response_type: "code",
            scope: def.scopes,
            state: state_key,
            code_challenge: challenge,
            code_challenge_method: "S256"
          }

          auth_url = "#{def.auth_url}?#{URI.encode_query(params)}"

          entry = %{
            provider_type: provider_type,
            user_id: user_id,
            verifier: verifier,
            redirect_uri: redirect_uri,
            expires_at: System.system_time(:second) + @state_ttl_seconds,
            status: :pending,
            provider: nil
          }

          :ets.insert(@table, {state_key, entry})

          {:reply, {:ok, %{auth_url: auth_url, state_key: state_key}}, state}
        end

      :error ->
        {:reply, {:error, "Unsupported OAuth provider: #{provider_type}"}, state}
    end
  end

  @impl true
  def handle_call({:handle_callback, code, state_key}, _from, state) do
    reply =
      case :ets.lookup(@table, state_key) do
        [] -> {:error, :state_not_found}
        [{^state_key, entry}] -> do_callback(entry, code, state_key)
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:sweep_expired, state) do
    now = System.system_time(:second)

    :ets.select_delete(@table, [
      {{:_, %{expires_at: :"$1"}}, [{:<, :"$1", now}], [true]}
    ])

    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_callback(entry, code, state_key) do
    if System.system_time(:second) > entry.expires_at do
      :ets.delete(@table, state_key)
      {:error, :state_expired}
    else
      case exchange_code(entry.provider_type, code, entry.verifier, entry.redirect_uri) do
        {:ok, token_data} ->
          provider_config = persist_provider(entry.provider_type, entry.user_id, token_data)
          updated = Map.merge(entry, %{status: :completed, provider: provider_config})
          :ets.insert(@table, {state_key, updated})
          {:ok, provider_config}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp generate_pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp generate_state_key do
    :crypto.strong_rand_bytes(20) |> Base.url_encode64(padding: false)
  end

  defp callback_uri do
    base = Application.get_env(:james, :base_url, "http://localhost:4000")
    "#{base}/api/providers/oauth/callback"
  end

  # Allows tests to inject custom provider definitions (e.g. Bypass URLs)
  # without touching production code.
  defp runtime_provider_defs do
    Application.get_env(:james, :oauth_provider_defs_override, @provider_defs)
  end

  defp exchange_code(provider_type, code, verifier, redirect_uri) do
    pdef = Map.fetch!(runtime_provider_defs(), provider_type)
    client_id = System.get_env(pdef.client_id_env, "")
    client_secret = System.get_env(pdef.client_secret_env, "")

    case Req.post(pdef.token_url,
           form: [
             grant_type: "authorization_code",
             code: code,
             redirect_uri: redirect_uri,
             client_id: client_id,
             client_secret: client_secret,
             code_verifier: verifier
           ]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           access_token: body["access_token"],
           refresh_token: body["refresh_token"],
           token_type: body["token_type"],
           expires_in: body["expires_in"]
         }}

      {:ok, %{body: body}} ->
        {:error, "Token exchange failed: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Token exchange request failed: #{inspect(reason)}"}
    end
  end

  defp persist_provider(provider_type, user_id, token_data) do
    attrs = %{
      user_id: user_id,
      host_id: nil,
      provider_type: provider_type,
      display_name: "#{String.capitalize(provider_type)} (OAuth)",
      auth_method: "oauth",
      api_key: token_data.access_token,
      status: "connected",
      last_tested_at: DateTime.utc_now()
    }

    case ProviderSettings.create_provider_config(attrs) do
      {:ok, config} -> config
      {:error, _} -> nil
    end
  end
end
