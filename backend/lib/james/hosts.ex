defmodule James.Hosts do
  @moduledoc """
  Manages registered hosts and their status.
  """

  import Ecto.Query
  alias James.Hosts.Host
  alias James.Repo

  def list_hosts do
    Repo.all(from h in Host, order_by: [desc: h.is_primary, asc: h.name])
  end

  def get_host(id), do: Repo.get(Host, id)

  def get_host!(id), do: Repo.get!(Host, id)

  def get_primary_host do
    Repo.get_by(Host, is_primary: true)
  end

  def create_host(attrs) do
    %Host{}
    |> Host.changeset(attrs)
    |> Repo.insert()
  end

  def update_host(%Host{} = host, attrs) do
    host
    |> Host.changeset(attrs)
    |> Repo.update()
  end

  def heartbeat(%Host{} = host) do
    update_host(host, %{last_seen_at: DateTime.utc_now(), status: "online"})
  end

  def list_sessions_for_host(host_id) do
    alias James.Sessions.Session
    Repo.all(from s in Session, where: s.host_id == ^host_id and s.status == "active")
  end
end
