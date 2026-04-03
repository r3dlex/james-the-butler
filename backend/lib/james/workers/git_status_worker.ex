defmodule James.Workers.GitStatusWorker do
  @moduledoc """
  Oban worker that fetches git status for a session's working directories
  and broadcasts the result to the session's PubSub topic.
  """

  use Oban.Worker, queue: :background, max_attempts: 2

  alias James.Codebase.GitParser
  alias James.Sessions
  alias Phoenix.PubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id, "user_id" => _user_id}}) do
    do_git_status(session_id)
  end

  def perform(%Oban.Job{args: _}), do: :ok

  defp do_git_status(session_id) do
    session = Sessions.get_session(session_id)

    if is_nil(session) or session.working_directories == [] do
      :ok
    else
      session.working_directories
      |> Enum.map(&fetch_git_status/1)
      |> Enum.reject(&is_nil/1)
      |> then(fn results ->
        if results != [] do
          PubSub.broadcast(
            James.PubSub,
            "session:#{session_id}",
            {:git_status_update, results}
          )
        end
      end)

      :ok
    end
  end

  defp fetch_git_status(dir) do
    with {:ok, status} <- GitParser.parse_status(dir),
         {:ok, diff_summary} <- GitParser.parse_diff_summary(dir) do
      %{dir: dir, status: status, diff_summary: diff_summary}
    else
      {:error, reason} ->
        %{dir: dir, error: reason}
    end
  end
end
