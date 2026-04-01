defmodule James.Desktop.DaemonTest do
  use ExUnit.Case, async: true

  alias James.Desktop.Daemon

  describe "status/0" do
    test "returns :disconnected" do
      assert Daemon.status() == :disconnected
    end
  end

  describe "execute/2" do
    test "returns daemon-not-running message when disconnected" do
      result = Daemon.execute("click", %{"x" => 100, "y" => 200})
      assert String.contains?(result, "not running")
    end

    test "works with default empty params" do
      result = Daemon.execute("screenshot")
      assert String.contains?(result, "not running")
    end
  end
end
