defmodule James.Channels.EventBus do
  @moduledoc """
  Routes external events from MCP servers into sessions via the meta-planner.
  Events are gated by sender_rules on the channel config.
  """

  alias James.{Channels, Planner.MetaPlanner}
  require Logger

  def route_event(channel_config_id, event) do
    case Channels.get_channel_config(channel_config_id) do
      nil ->
        {:error, :channel_not_found}

      config ->
        if allowed?(config, event) do
          session_id = config.session_id
          if session_id do
            Logger.info("Channel #{config.mcp_server}: routing event to session #{session_id}")
            message = %{
              role: "system",
              content: "[Channel: #{config.mcp_server}] #{event[:content] || inspect(event)}"
            }
            MetaPlanner.process_message(session_id, message)
            {:ok, :routed}
          else
            {:error, :no_session}
          end
        else
          {:error, :denied_by_rules}
        end
    end
  end

  defp allowed?(%{sender_rules: rules}, _event) when rules == %{}, do: true
  defp allowed?(%{sender_rules: %{"allow_all" => true}}, _event), do: true

  defp allowed?(%{sender_rules: %{"allowed_senders" => senders}}, event) do
    sender = event[:sender] || ""
    sender in senders
  end

  defp allowed?(_, _), do: true
end
