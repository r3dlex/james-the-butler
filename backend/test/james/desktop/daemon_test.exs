defmodule James.Desktop.DaemonTest do
  use ExUnit.Case, async: true

  alias James.Desktop.Daemon

  # ---------------------------------------------------------------------------
  # status/0 — backward-compat atom
  # ---------------------------------------------------------------------------

  describe "status/0" do
    test "returns :connected or :disconnected" do
      result = Daemon.status()
      assert result in [:connected, :disconnected]
    end

    test "returns :disconnected when daemon socket does not exist" do
      # Override the socket path to something that cannot exist
      System.put_env(
        "JAMES_DAEMON_SOCKET",
        "/tmp/james-daemon-no-such-socket-#{System.unique_integer()}.sock"
      )

      try do
        assert Daemon.status() == :disconnected
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # connected?/0
  # ---------------------------------------------------------------------------

  describe "connected?/0" do
    test "returns a boolean" do
      assert Daemon.connected?() in [true, false]
    end

    test "returns false when daemon socket file does not exist" do
      System.put_env(
        "JAMES_DAEMON_SOCKET",
        "/tmp/james-no-such-daemon-#{System.unique_integer()}.sock"
      )

      try do
        assert Daemon.connected?() == false
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # execute/2 — string legacy interface
  # ---------------------------------------------------------------------------

  describe "execute/2 — legacy string interface" do
    test "returns daemon-not-running message when given string action" do
      result = Daemon.execute("click", %{"x" => 100, "y" => 200})
      assert String.contains?(result, "not running")
    end

    test "works with default empty params for string action" do
      result = Daemon.execute("screenshot")
      assert String.contains?(result, "not running")
    end
  end

  # ---------------------------------------------------------------------------
  # execute/2 — atom interface
  # ---------------------------------------------------------------------------

  describe "execute/2 — atom interface when daemon is unavailable" do
    setup do
      # Point at a socket path that cannot exist so Daemon is always disconnected
      socket = "/tmp/james-test-daemon-#{System.unique_integer()}.sock"
      System.put_env("JAMES_DAEMON_SOCKET", socket)
      on_exit(fn -> System.delete_env("JAMES_DAEMON_SOCKET") end)
      :ok
    end

    test ":click returns {:error, :not_connected}" do
      assert {:error, :not_connected} = Daemon.execute(:click, %{x: 100, y: 200})
    end

    test ":screenshot returns {:error, :not_connected}" do
      assert {:error, :not_connected} = Daemon.execute(:screenshot, %{})
    end

    test ":type_text returns {:error, :not_connected}" do
      assert {:error, :not_connected} = Daemon.execute(:type_text, %{text: "hello"})
    end

    test ":key_press returns {:error, :not_connected}" do
      assert {:error, :not_connected} = Daemon.execute(:key_press, %{key: "enter"})
    end

    test ":scroll returns {:error, :not_connected}" do
      assert {:error, :not_connected} = Daemon.execute(:scroll, %{direction: "down", amount: 3})
    end

    test ":drag returns {:error, :not_connected}" do
      assert {:error, :not_connected} =
               Daemon.execute(:drag, %{from_x: 0, from_y: 0, to_x: 50, to_y: 50})
    end
  end
end
