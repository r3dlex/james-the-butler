defmodule James.Hosts.Cluster do
  @moduledoc """
  Manages multi-host architecture: registration, health monitoring, task routing.
  """

  alias James.Hosts
  require Logger

  def register_host(attrs), do: Hosts.create_host(attrs)

  def heartbeat(host_id) do
    case Hosts.get_host(host_id) do
      nil -> {:error, :not_found}
      host -> Hosts.heartbeat(host)
    end
  end

  def select_host_for_task(_task) do
    hosts = Hosts.list_hosts()
    online = Enum.filter(hosts, &(&1.status == "online"))

    case online do
      [] ->
        case Hosts.get_primary_host() do
          nil -> {:error, :no_hosts_available}
          host -> {:ok, host}
        end

      hosts ->
        {:ok, Enum.random(hosts)}
    end
  end

  def health_check_all do
    now = DateTime.utc_now()
    Hosts.list_hosts() |> Enum.each(fn host -> check_host_health(host, now) end)
  end

  defp check_host_health(%{last_seen_at: nil}, _now), do: :ok

  defp check_host_health(host, now) do
    age = DateTime.diff(now, host.last_seen_at, :second)

    cond do
      age > 120 and host.status != "offline" ->
        Logger.warning("Host #{host.name} offline — last seen #{age}s ago")
        Hosts.update_host(host, %{status: "offline"})

      age > 60 and host.status == "online" ->
        Logger.info("Host #{host.name} draining — last seen #{age}s ago")
        Hosts.update_host(host, %{status: "draining"})

      true ->
        :ok
    end
  end

  def status do
    hosts = Hosts.list_hosts()

    %{
      total: length(hosts),
      online: Enum.count(hosts, &(&1.status == "online")),
      draining: Enum.count(hosts, &(&1.status == "draining")),
      offline: Enum.count(hosts, &(&1.status == "offline")),
      primary: Enum.find(hosts, & &1.is_primary)
    }
  end
end
