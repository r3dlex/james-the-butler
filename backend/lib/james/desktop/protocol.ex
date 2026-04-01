defmodule James.Desktop.Protocol do
  @moduledoc """
  JSON protocol for communication with the native desktop daemon over a Unix
  socket.

  ## Wire format

  Commands are sent as newline-terminated JSON objects:

      {"action": "screenshot", ...params...}\\n

  Responses arrive as newline-terminated JSON objects:

      {"status": "ok", "data": {...}}\\n
      {"status": "error", "reason": "..."}\\n

  ## Supported actions

  | Atom           | Required params         |
  |----------------|-------------------------|
  | `:screenshot`  | _(none)_                |
  | `:click`       | `x`, `y`               |
  | `:type_text`   | `text`                  |
  | `:key_press`   | `key`                   |
  | `:scroll`      | `direction`, `amount`   |
  | `:drag`        | `from_x`, `from_y`, `to_x`, `to_y` |
  """

  @type action ::
          :screenshot
          | :click
          | :type_text
          | :key_press
          | :scroll
          | :drag

  @doc """
  Encode an `action` and its `params` map into a JSON binary suitable for
  sending over the daemon socket.

  Returns a JSON binary (without a trailing newline).
  """
  @spec encode(action(), map()) :: binary()
  def encode(action, params \\ %{}) when is_atom(action) do
    payload = Map.put(params, :action, Atom.to_string(action))
    Jason.encode!(payload)
  end

  @doc """
  Decode a JSON `binary` received from the daemon.

  Returns `{:ok, data}` for a success response or `{:error, reason}` for an
  error response or a malformed payload.
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, term()}
  def decode(binary) when is_binary(binary) do
    case Jason.decode(binary) do
      {:ok, %{"status" => "ok", "data" => data}} ->
        {:ok, data}

      {:ok, %{"status" => "error", "reason" => reason}} ->
        {:error, reason}

      {:ok, %{"status" => "ok"} = msg} ->
        # Response with no separate "data" key — return the whole map minus status
        {:ok, Map.delete(msg, "status")}

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, reason} ->
        {:error, {:json_decode, reason}}
    end
  end
end
