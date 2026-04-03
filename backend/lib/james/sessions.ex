defmodule James.Sessions do
  @moduledoc """
  Manages sessions and messages.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias James.Repo
  alias James.Sessions.{Checkpoint, Message, Session}

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

  def suspend_session(%Session{status: "active"} = session) do
    messages = list_messages(session.id)

    snapshot =
      Enum.map(messages, fn m ->
        %{role: m.role, content: m.content, inserted_at: m.inserted_at}
      end)

    checkpoint_attrs = %{
      session_id: session.id,
      type: "implicit",
      conversation_snapshot: %{messages: snapshot}
    }

    result =
      Multi.new()
      |> Multi.insert(:checkpoint, Checkpoint.changeset(%Checkpoint{}, checkpoint_attrs))
      |> Multi.update(:session, Session.changeset(session, %{status: "suspended"}))
      |> Repo.transaction()

    case result do
      {:ok, %{session: updated}} -> {:ok, updated}
      {:error, _op, changeset, _changes} -> {:error, changeset}
    end
  end

  def suspend_session(%Session{}), do: {:error, :invalid_transition}

  def resume_session(%Session{status: "suspended"} = session) do
    update_session(session, %{status: "active"})
  end

  def resume_session(%Session{}), do: {:error, :invalid_transition}

  def terminate_session(%Session{status: "terminated"}), do: {:error, :invalid_transition}

  def terminate_session(%Session{} = session) do
    update_session(session, %{status: "terminated"})
  end

  def touch_session(%Session{} = session) do
    update_session(session, %{last_used_at: DateTime.utc_now()})
  end

  def list_messages(session_id) do
    Repo.all(
      from m in Message,
        where: m.session_id == ^session_id,
        order_by: [asc: m.inserted_at, asc: m.id]
    )
  end

  @doc """
  Returns messages in a session that were inserted after the message with
  `after_message_id`. Used by the memory extraction worker for delta tracking.
  """
  def list_messages_after(session_id, after_message_id) do
    anchor_inserted_at =
      from(m in Message, where: m.id == ^after_message_id, select: m.inserted_at)
      |> Repo.one()

    if is_nil(anchor_inserted_at) do
      list_messages(session_id)
    else
      Repo.all(
        from m in Message,
          where:
            m.session_id == ^session_id and
              m.id != ^after_message_id and
              m.inserted_at >= ^anchor_inserted_at,
          order_by: [asc: m.inserted_at, asc: m.id]
      )
    end
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def message_count(session_id) do
    Repo.aggregate(from(m in Message, where: m.session_id == ^session_id), :count)
  end

  # --- Checkpoints ---

  def create_checkpoint(attrs) do
    %Checkpoint{}
    |> Checkpoint.changeset(attrs)
    |> Repo.insert()
  end

  def list_checkpoints(session_id) do
    from(c in Checkpoint, where: c.session_id == ^session_id, order_by: [desc: c.inserted_at])
    |> Repo.all()
  end

  def get_checkpoint(id), do: Repo.get(Checkpoint, id)

  def create_implicit_checkpoint(session_id) do
    messages = list_messages(session_id)

    snapshot =
      Enum.map(messages, fn m ->
        %{role: m.role, content: m.content, inserted_at: m.inserted_at}
      end)

    create_checkpoint(%{
      session_id: session_id,
      type: "implicit",
      conversation_snapshot: %{messages: snapshot}
    })
  end

  def create_explicit_checkpoint(session_id, name) do
    messages = list_messages(session_id)

    snapshot =
      Enum.map(messages, fn m ->
        %{role: m.role, content: m.content, inserted_at: m.inserted_at}
      end)

    create_checkpoint(%{
      session_id: session_id,
      type: "explicit",
      name: name,
      conversation_snapshot: %{messages: snapshot}
    })
  end

  def rewind_to_checkpoint(checkpoint_id) do
    case get_checkpoint(checkpoint_id) do
      nil ->
        {:error, :not_found}

      checkpoint ->
        # Delete all messages in the session
        from(m in Message, where: m.session_id == ^checkpoint.session_id)
        |> Repo.delete_all()

        # Restore messages from snapshot
        messages = get_in(checkpoint.conversation_snapshot, ["messages"]) || []

        Enum.each(messages, fn msg ->
          create_message(%{
            session_id: checkpoint.session_id,
            role: msg["role"],
            content: msg["content"]
          })
        end)

        {:ok, checkpoint}
    end
  end
end
