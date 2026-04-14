defmodule JamesCli.Auth do
  @moduledoc """
  Authentication for the James CLI using device code flow.

  First login: device code flow (requires browser). Stores token in ~/.james/token.
  Subsequent logins: token loaded from ~/.james/token automatically.
  """

  @token_path Path.join(
                Path.join(System.get_env("HOME") || System.user_home!(), ".james"),
                "token"
              )

  @doc """
  Performs device code login. Fetches device code from server, displays user code,
  polls until user authenticates, then stores and returns the token.
  """
  def login_with_device_code(api_url) do
    case fetch_device_code(api_url) do
      {:ok, %{"user_code" => user_code, "device_code" => device_code}} ->
        IO.puts("\n=== James CLI Login ===")

        IO.puts(
          "Open your browser and enter this code: #{IO.ANSI.bright()}#{user_code}#{IO.ANSI.reset()}"
        )

        IO.puts("Waiting for authentication...\n")

        poll_for_token(api_url, device_code)

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp fetch_device_code(api_url) do
    url = "#{api_url}/api/auth/device-code"

    case Req.post(url, json: %{}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Device code request failed: #{status} — #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp poll_for_token(api_url, device_code) do
    url = "#{api_url}/api/auth/device-code/token"

    # Poll every 2 seconds, up to 300 times (10 minutes)
    Enum.reduce_while(1..300, nil, fn _attempt, _acc ->
      Process.sleep(2000)

      case Req.post(url, json: %{"device_code" => device_code}) do
        {:ok, %{status: 200, body: %{"token" => token}}} ->
          case save_token(token) do
            :ok ->
              IO.puts("#{IO.ANSI.green()}✓#{IO.ANSI.reset()} Login successful!")
              {:halt, {:ok, token}}

            {:error, reason} ->
              {:halt, {:error, "Login succeeded but could not save token: #{inspect(reason)}"}}
          end

        {:ok, %{status: 200, body: %{"pending" => true}}} ->
          {:cont, :pending}

        {:ok, %{status: 200, body: %{"error" => error}}} ->
          {:halt, {:error, "Authentication failed: #{error}"}}

        {:ok, %{status: status, body: body}} ->
          {:halt, {:error, "Unexpected response: #{status} — #{inspect(body)}"}}

        {:error, reason} ->
          {:halt, {:error, "Network error: #{inspect(reason)}"}}
      end
    end)

    # credo:disable-next-line Credo.Check.Refactor.Nesting
  end

  @doc """
  Loads the stored token from ~/.james/token.
  Returns {:ok, token} or {:error, :not_found}.
  """
  def load_token do
    case File.read(@token_path) do
      {:ok, token} -> {:ok, String.trim(token)}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Saves a token to ~/.james/token.
  Returns :ok or {:error, reason}.
  """
  def save_token(token) do
    token_dir = Path.dirname(@token_path)
    File.mkdir_p(token_dir)
    File.write(@token_path, token)
  end

  @doc """
  Clears the stored token (logout).
  """
  def clear_token do
    case File.rm(@token_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the token path for reference."
  def token_path, do: @token_path
end
