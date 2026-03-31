defmodule JamesWeb.ChannelConfigController do
  use Phoenix.Controller, formats: [:json]

  alias James.Channels

  def index(conn, _params) do
    user = conn.assigns.current_user
    configs = Channels.list_channel_configs(user.id)
    json(conn, %{channel_configs: Enum.map(configs, &config_json/1)})
  end

  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "user_id", user.id)

    case Channels.create_channel_config(attrs) do
      {:ok, config} -> conn |> put_status(:created) |> json(%{channel_config: config_json(config)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Channels.get_channel_config(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      config ->
        {:ok, _} = Channels.delete_channel_config(config)
        json(conn, %{ok: true})
    end
  end

  defp config_json(c) do
    %{
      id: c.id,
      mcp_server: c.mcp_server,
      config: c.config,
      sender_rules: c.sender_rules,
      session_id: c.session_id,
      inserted_at: c.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
