defmodule James.Browser.CdpManager do
  @moduledoc """
  Manages Chrome browser instances and CDP (Chrome DevTools Protocol) connections.

  Provides a high-level interface for browser automation: it checks whether Chrome
  is reachable on the debugger port, delegates individual actions to `CdpClient`,
  and exposes a `status/0` helper so callers can branch on connectivity.

  ## Chrome setup

  Start Chrome with remote debugging enabled before calling `ensure_chrome/0`:

      google-chrome --remote-debugging-port=9222 --headless

  The default port is `9222`.  Override it by setting the `CDP_PORT` environment
  variable.

  ## Actions

  `execute/2` accepts the following action atoms:

    * `:navigate`   – navigate to a URL (`params.url`)
    * `:screenshot` – capture a PNG screenshot (returns base64 data)
    * `:evaluate`   – evaluate a JavaScript expression (`params.expression`)

  Legacy string-based actions used by the original scaffold are still supported
  for backward compatibility.
  """

  alias James.Browser.CdpClient

  require Logger

  @cdp_port 9222

  # ---------------------------------------------------------------------------
  # Port helpers
  # ---------------------------------------------------------------------------

  defp cdp_port do
    case System.get_env("CDP_PORT") do
      nil -> @cdp_port
      val -> String.to_integer(val)
    end
  end

  defp port_open?(port) do
    case :gen_tcp.connect(~c"localhost", port, [:binary, active: false], 500) do
      {:ok, sock} ->
        :gen_tcp.close(sock)
        true

      {:error, _} ->
        false
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Return `:running` if the Chrome debugger port is reachable, `:stopped` otherwise.
  """
  @spec status() :: :running | :stopped
  def status do
    if port_open?(cdp_port()), do: :running, else: :stopped
  end

  @doc """
  Ensure a Chrome instance is available for CDP connections.

  Returns `:ok` when either:
    * The Chrome debugger port is reachable (Chrome already running with CDP), or
    * A `google-chrome` or `chromium` executable is found in `PATH` (Chrome can
      be launched on demand).

  Returns `{:error, instructions}` with human-readable startup instructions when
  neither condition is met.
  """
  @spec ensure_chrome() :: :ok | {:error, String.t()}
  def ensure_chrome do
    cond do
      port_open?(cdp_port()) ->
        :ok

      chrome_executable() != nil ->
        :ok

      true ->
        {:error,
         "Chrome is not running with remote debugging enabled. " <>
           "Start it with: google-chrome --remote-debugging-port=#{cdp_port()} --headless"}
    end
  end

  defp chrome_executable do
    System.find_executable("google-chrome") || System.find_executable("chromium")
  end

  @doc """
  Execute a browser action via CDP.

  Atom-based actions (new interface):
    * `execute(:navigate, %{url: url})`   → `{:ok, result}` | `{:error, reason}`
    * `execute(:screenshot, %{})`         → `{:ok, %{data: base64}}` | `{:error, reason}`
    * `execute(:evaluate, %{expression: expr})` → `{:ok, result}` | `{:error, reason}`

  String-based actions (legacy scaffold, returns binary strings):
    * `"navigate"`, `"click_element"`, `"fill_form"`, `"get_page_content"`,
      `"run_javascript"`, `"screenshot_page"`, and anything else.
  """
  @spec execute(atom() | String.t(), map()) :: {:ok, map()} | {:error, term()} | String.t()
  def execute(action, params \\ %{})

  # --- Atom-based interface ---------------------------------------------------

  def execute(:navigate, %{url: url}) do
    with_client(fn client -> CdpClient.navigate(client, url) end)
  end

  def execute(:screenshot, _params) do
    with_client(fn client -> CdpClient.screenshot(client) end)
  end

  def execute(:evaluate, %{expression: expression}) do
    with_client(fn client -> CdpClient.evaluate(client, expression) end)
  end

  # --- Legacy string-based interface -----------------------------------------

  def execute(action, params) when is_binary(action) do
    Logger.info("CDP: #{action} with #{inspect(params)}")

    case action do
      "navigate" ->
        url = Map.get(params, "url", "")
        "Navigated to: #{url}"

      "click_element" ->
        selector = Map.get(params, "selector", "")
        "Clicked element: #{selector}"

      "fill_form" ->
        selector = Map.get(params, "selector", "")
        "Filled form field: #{selector}"

      "get_page_content" ->
        "Page content: [CDP connection not established]"

      "run_javascript" ->
        "JavaScript execution: [CDP connection not established]"

      "screenshot_page" ->
        "Screenshot: [CDP connection not established]"

      _ ->
        "Unknown browser action: #{action}"
    end
  end

  @doc "Close all tab groups that have been idle since `cutoff` datetime."
  def close_idle_tab_groups(_cutoff) do
    # Scaffold: in production, query active tab groups from registry and
    # close any whose last_activity < cutoff via CDP Target.closeTarget.
    Logger.info("CDP: close_idle_tab_groups called")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Start a one-shot CdpClient, run the given function, and stop the client.
  defp with_client(fun) do
    page_id = "page"
    url = "ws://localhost:#{cdp_port()}/devtools/page/#{page_id}"

    case CdpClient.start_link([]) do
      {:ok, client} ->
        result =
          case CdpClient.connect(client, url) do
            :ok -> fun.(client)
            {:error, reason} -> {:error, reason}
          end

        GenServer.stop(client, :normal)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end
end
