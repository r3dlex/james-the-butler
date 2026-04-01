defmodule James.Channels.TelegramThread do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "telegram_threads" do
    field :telegram_thread_id, :integer
    belongs_to :session, James.Sessions.Session
    belongs_to :user, James.Accounts.User
    field :inserted_at, :utc_datetime
  end

  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:telegram_thread_id, :session_id, :user_id])
    |> validate_required([:telegram_thread_id, :session_id, :user_id])
    |> unique_constraint(:telegram_thread_id)
  end
end
