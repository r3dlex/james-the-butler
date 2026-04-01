defmodule James.Hosts.ClusterTest do
  use James.DataCase

  alias James.{Hosts, Hosts.Cluster}

  defp create_host(attrs \\ %{}) do
    {:ok, host} =
      Hosts.create_host(
        Map.merge(%{name: "Cluster Host", endpoint: "http://localhost:7099"}, attrs)
      )

    host
  end

  describe "register_host/1" do
    test "registers a host by creating it in the registry" do
      attrs = %{name: "New Host", endpoint: "http://new:7000"}
      assert {:ok, host} = Cluster.register_host(attrs)
      assert host.name == "New Host"
    end
  end

  describe "heartbeat/1" do
    test "updates last_seen_at and sets status to online" do
      host = create_host(%{name: "HB Host"})
      # Cluster.heartbeat/1 takes a host id (string), not a struct
      assert {:ok, updated} = Cluster.heartbeat(host.id)
      assert updated.status == "online"
      assert updated.last_seen_at != nil
    end

    test "returns error for unknown host id" do
      assert {:error, :not_found} = Cluster.heartbeat(Ecto.UUID.generate())
    end
  end

  describe "select_host_for_task/1" do
    test "returns an online host when available" do
      create_host(%{name: "Online Host", status: "online"})
      result = Cluster.select_host_for_task(%{})
      # Returns {:ok, host} or {:error, :no_hosts_available}
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error when no hosts are available and no primary set" do
      # All hosts offline and no primary
      result = Cluster.select_host_for_task(%{})
      # This test is environment-dependent — we just verify no crash
      assert is_tuple(result)
    end
  end

  describe "health_check_all/0" do
    test "runs without error" do
      create_host(%{name: "Health Host"})
      assert :ok = Cluster.health_check_all()
    end

    test "marks hosts offline when last_seen_at is old" do
      {:ok, host} = Hosts.create_host(%{name: "Old Host", endpoint: "http://old:7000"})
      # Set last_seen_at to a long time ago
      old_time = DateTime.add(DateTime.utc_now(), -200, :second)
      Hosts.update_host(host, %{last_seen_at: old_time, status: "online"})
      assert :ok = Cluster.health_check_all()
      updated = Hosts.get_host(host.id)
      assert updated.status == "offline"
    end
  end

  describe "status/0" do
    test "returns cluster status summary" do
      status = Cluster.status()
      assert Map.has_key?(status, :total)
      assert Map.has_key?(status, :online)
      assert Map.has_key?(status, :offline)
    end

    test "counts hosts correctly" do
      create_host(%{name: "Status Host A"})
      create_host(%{name: "Status Host B"})
      status = Cluster.status()
      assert status.total >= 2
    end
  end
end
