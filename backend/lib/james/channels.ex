defmodule James.Channels do
  @moduledoc "Manages channel configurations for external event sources."

  import Ecto.Query
  alias James.Channels.ChannelConfig
  alias James.Repo

  def list_channel_configs(user_id) do
    from(c in ChannelConfig, where: c.user_id == ^user_id, order_by: [asc: c.mcp_server])
    |> Repo.all()
  end

  def get_channel_config(id), do: Repo.get(ChannelConfig, id)

  def create_channel_config(attrs) do
    %ChannelConfig{}
    |> ChannelConfig.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel_config(%ChannelConfig{} = config, attrs) do
    config
    |> ChannelConfig.changeset(attrs)
    |> Repo.update()
  end

  def delete_channel_config(%ChannelConfig{} = config) do
    Repo.delete(config)
  end
end
