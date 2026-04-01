defmodule James.Browser.CdpClientTest do
  use ExUnit.Case, async: true

  alias James.Browser.CdpClient

  # ---------------------------------------------------------------------------
  # In-process mock transport
  #
  # The mock records calls and, for send_frame/2, immediately delivers a
  # synthetic response back to the CdpClient owner so that `send_command`
  # callers are unblocked.
  # ---------------------------------------------------------------------------

  defmodule MockTransport do
    @moduledoc false

    # connect/2 – always succeeds; stores owner PID in the "connection"
    def connect(_url, owner) do
      {:ok, %{owner: owner, mode: :ok}}
    end

    # Variant that always fails
    def connect_error(_url, _owner) do
      {:error, :econnrefused}
    end

    # send_frame/2 – decodes the frame, builds a matching result, and delivers
    # it back to the owner as {:cdp_frame, binary}.
    def send_frame(%{owner: owner}, frame) do
      case Jason.decode(frame) do
        {:ok, %{"id" => id, "method" => method}} ->
          result = synthetic_result(method)
          response = Jason.encode!(%{"id" => id, "result" => result})
          send(owner, {:cdp_frame, response})
          :ok

        _ ->
          {:error, :bad_frame}
      end
    end

    # send_frame that simulates a transport-level error
    def send_frame_error(_conn, _frame), do: {:error, :closed}

    defp synthetic_result("Page.navigate"), do: %{"frameId" => "frame-1"}

    defp synthetic_result("Runtime.evaluate"),
      do: %{"result" => %{"type" => "number", "value" => 42}}

    defp synthetic_result("Page.captureScreenshot"), do: %{"data" => "aGVsbG8="}
    defp synthetic_result(_method), do: %{"ok" => true}
  end

  # A transport whose connect/2 rejects the connection
  defmodule FailingTransport do
    @moduledoc false
    def connect(_url, _owner), do: {:error, :econnrefused}
    def send_frame(_conn, _frame), do: {:error, :closed}
  end

  # A transport whose send_frame always fails
  defmodule SendFailTransport do
    @moduledoc false
    def connect(_url, owner), do: {:ok, %{owner: owner}}
    def send_frame(_conn, _frame), do: {:error, :closed}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp start_connected(transport \\ MockTransport) do
    {:ok, pid} = CdpClient.start_link(transport: transport)
    :ok = CdpClient.connect(pid, "ws://localhost:9222/devtools/page/test")
    pid
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "connect/2" do
    test "returns :ok when transport connects successfully" do
      {:ok, pid} = CdpClient.start_link(transport: MockTransport)
      assert :ok = CdpClient.connect(pid, "ws://localhost:9222/devtools/page/abc")
    end

    test "returns {:error, reason} when transport fails to connect" do
      {:ok, pid} = CdpClient.start_link(transport: FailingTransport)

      assert {:error, :econnrefused} =
               CdpClient.connect(pid, "ws://localhost:9222/devtools/page/abc")
    end
  end

  describe "send_command/3" do
    test "sends a JSON-RPC command and returns the result" do
      pid = start_connected()

      assert {:ok, result} =
               CdpClient.send_command(pid, "Page.navigate", %{"url" => "https://example.com"})

      assert is_map(result)
    end

    test "returns {:error, :not_connected} when no connection established" do
      {:ok, pid} = CdpClient.start_link(transport: MockTransport)
      assert {:error, :not_connected} = CdpClient.send_command(pid, "Page.navigate", %{})
    end

    test "returns {:error, reason} when transport send_frame fails" do
      {:ok, pid} = CdpClient.start_link(transport: SendFailTransport)
      :ok = CdpClient.connect(pid, "ws://localhost:9222/devtools/page/fail")
      assert {:error, :closed} = CdpClient.send_command(pid, "Page.navigate", %{})
    end

    test "handles error response from CDP" do
      defmodule ErrorTransport do
        @moduledoc false
        def connect(_url, owner), do: {:ok, %{owner: owner}}

        def send_frame(%{owner: owner}, frame) do
          {:ok, %{"id" => id}} = Jason.decode(frame)
          response = Jason.encode!(%{"id" => id, "error" => %{"message" => "Target closed"}})
          send(owner, {:cdp_frame, response})
          :ok
        end
      end

      {:ok, pid} = CdpClient.start_link(transport: ErrorTransport)
      :ok = CdpClient.connect(pid, "ws://localhost:9222/devtools/page/err")

      assert {:error, %{"message" => "Target closed"}} =
               CdpClient.send_command(pid, "Page.navigate", %{})
    end
  end

  describe "navigate/2" do
    test "sends Page.navigate and returns frameId" do
      pid = start_connected()
      assert {:ok, %{"frameId" => _}} = CdpClient.navigate(pid, "https://example.com")
    end
  end

  describe "evaluate/2" do
    test "sends Runtime.evaluate and returns result" do
      pid = start_connected()
      assert {:ok, result} = CdpClient.evaluate(pid, "1 + 1")
      assert get_in(result, ["result", "type"]) == "number"
    end
  end

  describe "screenshot/1" do
    test "sends Page.captureScreenshot and returns base64 data" do
      pid = start_connected()
      assert {:ok, %{"data" => data}} = CdpClient.screenshot(pid)
      assert is_binary(data)
      # Verify it is valid base64
      assert {:ok, _decoded} = Base.decode64(data)
    end
  end
end
