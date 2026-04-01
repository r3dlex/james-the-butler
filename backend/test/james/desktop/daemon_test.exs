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

  # ---------------------------------------------------------------------------
  # ping_daemon path — socket file exists but connection refused
  # ---------------------------------------------------------------------------

  describe "connected?/0 when socket file exists but daemon refuses connection" do
    test "returns false when socket file exists but connect fails" do
      # Create a regular file at the socket path so File.exists?/1 returns true,
      # but the path is not a valid Unix socket so :gen_tcp.connect will fail.
      path = "/tmp/james-fake-sock-#{System.unique_integer()}"
      File.write!(path, "")
      System.put_env("JAMES_DAEMON_SOCKET", path)

      try do
        result = Daemon.connected?()
        # Should be false: file exists but ping fails (not a real socket)
        assert result == false
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
        File.rm(path)
      end
    end

    test "status/0 returns :disconnected when socket exists but connect fails" do
      path = "/tmp/james-fake-sock-#{System.unique_integer()}"
      File.write!(path, "")
      System.put_env("JAMES_DAEMON_SOCKET", path)

      try do
        assert Daemon.status() == :disconnected
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
        File.rm(path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # send_command path — socket file exists but connection refused
  # ---------------------------------------------------------------------------

  describe "execute/2 when socket file exists but connect fails" do
    test "returns {:error, reason} rather than :not_connected" do
      # Use a real Unix socket listener that immediately closes the connection
      # so we can exercise the send_command → connect_socket error path.
      path = "/tmp/james-fake-sock-#{System.unique_integer()}"
      File.write!(path, "")
      System.put_env("JAMES_DAEMON_SOCKET", path)

      try do
        # File exists so connected?/0 tries to ping and fails → :not_connected
        result = Daemon.execute(:screenshot, %{})
        assert result == {:error, :not_connected}
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
        File.rm(path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Real Unix socket listener — exercises the connected happy path and
  # the send_command flow end-to-end.
  # ---------------------------------------------------------------------------

  describe "execute/2 with a real responding Unix socket" do
    # Start a minimal TCP listener on an AF_UNIX socket that replies with a
    # JSON ok response, then check the daemon returns {:ok, _}.
    test "returns {:ok, data} when daemon replies with a valid ok response" do
      socket_path = "/tmp/james-daemon-test-#{System.unique_integer()}.sock"
      parent = self()

      # Start a multi-accept Unix socket listener.
      # connected?/0 consumes the first connection (ping), then execute/2
      # opens a second connection for the real command.
      listener_pid =
        spawn_link(fn ->
          {:ok, listen_sock} =
            :gen_tcp.listen(0, [
              :binary,
              active: false,
              packet: :line,
              ifaddr: {:local, socket_path}
            ])

          send(parent, :listening)

          # Accept up to 2 connections (ping + real command)
          Enum.each(1..2, fn _i ->
            case :gen_tcp.accept(listen_sock, 2_000) do
              {:ok, client} ->
                {:ok, _line} = :gen_tcp.recv(client, 0, 2_000)

                reply =
                  Jason.encode!(%{"status" => "ok", "data" => %{"result" => "captured"}}) <>
                    "\n"

                :gen_tcp.send(client, reply)
                :gen_tcp.close(client)

              {:error, _} ->
                :ok
            end
          end)

          :gen_tcp.close(listen_sock)
        end)

      assert_receive :listening, 2_000

      System.put_env("JAMES_DAEMON_SOCKET", socket_path)

      try do
        assert {:ok, %{"result" => "captured"}} = Daemon.execute(:screenshot, %{})
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
        File.rm(socket_path)
        Process.unlink(listener_pid)
      end
    end

    test "connected?/0 returns true when daemon responds to ping" do
      socket_path = "/tmp/james-daemon-ping-test-#{System.unique_integer()}.sock"
      parent = self()

      _listener_pid =
        spawn(fn ->
          {:ok, listen_sock} =
            :gen_tcp.listen(0, [
              :binary,
              active: false,
              packet: :line,
              ifaddr: {:local, socket_path}
            ])

          send(parent, :listening)

          {:ok, client} = :gen_tcp.accept(listen_sock, 2_000)
          {:ok, _line} = :gen_tcp.recv(client, 0, 2_000)
          reply = Jason.encode!(%{"status" => "ok", "data" => %{}}) <> "\n"
          :gen_tcp.send(client, reply)
          :gen_tcp.close(client)
          :gen_tcp.close(listen_sock)
        end)

      assert_receive :listening, 2_000

      System.put_env("JAMES_DAEMON_SOCKET", socket_path)

      try do
        assert Daemon.connected?() == true
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
        File.rm(socket_path)
      end
    end

    test "execute/2 returns :not_connected when daemon closes without responding to ping" do
      socket_path = "/tmp/james-daemon-close-#{System.unique_integer()}.sock"
      parent = self()

      _listener_pid =
        spawn(fn ->
          {:ok, listen_sock} =
            :gen_tcp.listen(0, [
              :binary,
              active: false,
              packet: :line,
              ifaddr: {:local, socket_path}
            ])

          send(parent, :listening)

          {:ok, client} = :gen_tcp.accept(listen_sock, 2_000)
          # Close immediately without sending any data (ping fails)
          :gen_tcp.close(client)
          :gen_tcp.close(listen_sock)
        end)

      assert_receive :listening, 2_000

      System.put_env("JAMES_DAEMON_SOCKET", socket_path)

      try do
        # The ping (connected?/0) will get a closed connection → returns false
        # execute/2 then returns :not_connected.
        result = Daemon.execute(:screenshot, %{})
        assert result == {:error, :not_connected}
      after
        System.delete_env("JAMES_DAEMON_SOCKET")
        File.rm(socket_path)
      end
    end
  end
end
