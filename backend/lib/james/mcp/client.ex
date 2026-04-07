defmodule James.MCP.Client do
  @moduledoc """
  JSON-RPC 2.0 message builder and parser for MCP protocol.
  All MCP servers communicate using JSON-RPC over their respective transports.
  """

  @json_rpc_version "2.0"

  # Build JSON-RPC request
  def build_request(method, params \\ %{}) do
    %{
      "jsonrpc" => @json_rpc_version,
      "id" => System.unique_integer([:positive]),
      "method" => method,
      "params" => params
    }
  end

  # Build a tools/call request
  def build_tool_call(tool_name, arguments) do
    build_request("tools/call", %{
      "name" => tool_name,
      "arguments" => arguments
    })
  end

  # Parse a JSON-RPC response
  def parse_response(%{"jsonrpc" => "2.0", "id" => id, "result" => result}) do
    {:ok, id, result}
  end

  def parse_response(%{"jsonrpc" => "2.0", "id" => id, "error" => error}) do
    {:error, id, error}
  end

  def parse_response(other) do
    {:error, :invalid_response, other}
  end

  # Extract tool result from a tools/call response
  # MCP returns result.content as an array of content blocks
  def extract_tool_result(%{"content" => content}) when is_list(content) do
    content
    |> Enum.map(fn block ->
      case block do
        %{"type" => "text", "text" => text} -> text
        %{"type" => "image", "data" => _data, "mimeType" => mime} -> "[image #{mime}]"
        other -> inspect(other)
      end
    end)
    |> Enum.join("\n")
  end

  def extract_tool_result(other), do: inspect(other)

  def send_request(transport_state, request) do
    case Jason.encode(request) do
      {:ok, encoded} ->
        case James.MCP.Transports.send_and_receive(transport_state, encoded) do
          {:ok, response_raw} ->
            case Jason.decode(response_raw, keys: :strings) do
              {:ok, response} -> parse_response(response)
              error -> {:error, :json_decode_failed, error}
            end

          {:error, _reason} = error ->
            error
        end

      {:error, _reason} = error ->
        error
    end
  end

  # Convenience: list tools
  def list_tools(transport_state) do
    request = build_request("tools/list")

    case send_request(transport_state, request) do
      {:ok, _id, %{"tools" => tools}} -> {:ok, tools}
      {:ok, _id, _other} -> {:ok, []}
      error -> error
    end
  end

  # Convenience: call a tool
  def call_tool(transport_state, tool_name, arguments) do
    request = build_tool_call(tool_name, arguments)

    case send_request(transport_state, request) do
      {:ok, _id, result} -> {:ok, extract_tool_result(result)}
      {:error, _id, error} -> {:error, error}
      error -> error
    end
  end
end
