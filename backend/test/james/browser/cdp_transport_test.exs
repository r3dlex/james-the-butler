defmodule James.Browser.CdpTransportTest do
  use ExUnit.Case, async: true

  alias James.Browser.CdpTransport

  describe "connect/2" do
    test "returns {:error, :not_implemented}" do
      assert {:error, :not_implemented} =
               CdpTransport.connect("ws://localhost:9222/devtools/page/test", self())
    end

    test "returns {:error, :not_implemented} regardless of url" do
      assert {:error, :not_implemented} =
               CdpTransport.connect("ws://example.com/any/path", self())
    end

    test "returns {:error, :not_implemented} for any owner pid" do
      {:ok, pid} = Agent.start_link(fn -> :ok end)

      assert {:error, :not_implemented} =
               CdpTransport.connect("ws://localhost:9222/devtools/page/x", pid)

      Agent.stop(pid)
    end
  end

  describe "send_frame/2" do
    test "returns {:error, :not_implemented}" do
      assert {:error, :not_implemented} = CdpTransport.send_frame(:some_conn, "frame data")
    end

    test "returns {:error, :not_implemented} for any connection and frame" do
      assert {:error, :not_implemented} =
               CdpTransport.send_frame(%{socket: :socket_ref}, ~s({"id":1,"method":"test"}))
    end

    test "returns {:error, :not_implemented} for nil connection" do
      assert {:error, :not_implemented} = CdpTransport.send_frame(nil, "data")
    end
  end
end
