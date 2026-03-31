defmodule James.HostsTest do
  use James.DataCase

  alias James.Hosts

  defp create_host(attrs \\ %{}) do
    {:ok, host} = Hosts.create_host(Map.merge(%{name: "Test Host"}, attrs))
    host
  end

  describe "create_host/1" do
    test "creates a host with a name" do
      assert {:ok, host} = Hosts.create_host(%{name: "Workstation"})
      assert host.name == "Workstation"
    end

    test "defaults status to offline" do
      {:ok, host} = Hosts.create_host(%{name: "Default Host"})
      assert host.status == "offline"
    end

    test "defaults is_primary to false" do
      {:ok, host} = Hosts.create_host(%{name: "Secondary Host"})
      assert host.is_primary == false
    end

    test "fails when name is missing" do
      assert {:error, changeset} = Hosts.create_host(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid status" do
      assert {:error, changeset} = Hosts.create_host(%{name: "Bad", status: "unknown"})
      assert %{status: [_]} = errors_on(changeset)
    end

    test "creates host with endpoint" do
      {:ok, host} = Hosts.create_host(%{name: "Remote", endpoint: "https://host.example.com"})
      assert host.endpoint == "https://host.example.com"
    end
  end

  describe "list_hosts/0" do
    test "returns all hosts" do
      create_host(%{name: "Host A"})
      create_host(%{name: "Host B"})
      hosts = Hosts.list_hosts()
      assert length(hosts) >= 2
    end

    test "returns empty list when no hosts" do
      hosts = Hosts.list_hosts()
      assert hosts == []
    end

    test "primary hosts appear first" do
      create_host(%{name: "Secondary", is_primary: false})
      create_host(%{name: "Primary", is_primary: true})
      hosts = Hosts.list_hosts()
      assert hd(hosts).is_primary == true
    end
  end

  describe "get_host/1" do
    test "returns host by id" do
      host = create_host(%{name: "Findable"})
      assert found = Hosts.get_host(host.id)
      assert found.id == host.id
    end

    test "returns nil for unknown id" do
      assert Hosts.get_host(Ecto.UUID.generate()) == nil
    end
  end

  describe "update_host/2" do
    test "updates status" do
      host = create_host()
      assert {:ok, updated} = Hosts.update_host(host, %{status: "online"})
      assert updated.status == "online"
    end

    test "updates last_seen_at" do
      host = create_host()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      assert {:ok, updated} = Hosts.update_host(host, %{last_seen_at: now})
      assert updated.last_seen_at == now
    end

    test "updates name" do
      host = create_host(%{name: "Old Name"})
      assert {:ok, updated} = Hosts.update_host(host, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "heartbeat sets status to online and updates last_seen_at" do
      host = create_host()
      assert {:ok, updated} = Hosts.heartbeat(host)
      assert updated.status == "online"
      assert updated.last_seen_at != nil
    end
  end
end
