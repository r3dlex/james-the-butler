defmodule James.Sessions do
  @moduledoc """
  Manages sessions and messages.
  """

  import Ecto.Query
  alias James.Repo
  alias James.Sessions.{Session, Message}

  def list_sessions(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    cursor = Keyword.get(opts, :cursor)

    query =
      from s in Session,
        where: s.user_id == ^user_id and s.status != "archived",
        order_by: [desc: s.last_used_at, desc: s.inserted_at],
        limit: ^limit,
        preload: [:host, :project]

    query =
      if cursor do
        from s in query, where: s.inserted_at < ^cursor
      else
        query
      end

    Repo.all(query)
  end

  def get_session(id), do: Repo.get(Session, id)

  def get_session!(id), do: Repo.get!(Session, id)

  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def archive_session(%Session{} = session) do
    update_session(session, %{status: "archived"})
  end

  def touch_session(%Session{} = session) do
    update_session(session, %{last_used_at: DateTime.utc_now()})
  end

  def list_messages(session_id) do
    Repo.all(
      from m in Message,
        where: m.session_id == ^session_id,
        order_by: [asc: m.inserted_at]
    )
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def message_count(session_id) do
    Repo.aggregate(from(m in Message, where: m.session_id == ^session_id), :count)
  end
end
