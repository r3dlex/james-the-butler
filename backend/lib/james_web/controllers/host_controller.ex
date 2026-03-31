defmodule JamesWeb.HostController do
  use Phoenix.Controller, formats: [:json]

  alias James.Hosts

  def index(conn, _params) do
    hosts = Hosts.list_hosts()
    conn |> json(%{hosts: Enum.map(hosts, &host_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Hosts.get_host(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      host -> conn |> json(%{host: host_json(host)})
    end
  end

  def sessions(conn, %{"id" => id}) do
    case Hosts.get_host(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})
      _host ->
        sessions = Hosts.list_sessions_for_host(id)
        conn |> json(%{sessions: Enum.map(sessions, fn s -> %{id: s.id, name: s.name, status: s.status} end)})
    end
  end

  defp host_json(host) do
    %{
      id: host.id,
      name: host.name,
      endpoint: host.endpoint,
      status: host.status,
      is_primary: host.is_primary,
      mtls_cert_fingerprint: host.mtls_cert_fingerprint,
      last_seen_at: host.last_seen_at
    }
  end
end
