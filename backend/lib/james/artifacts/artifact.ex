defmodule James.Artifacts.Artifact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "artifacts" do
    field :type, :string
    field :path, :string
    field :is_deliverable, :boolean, default: false
    field :inserted_at, :utc_datetime
    field :cleaned_at, :utc_datetime

    field :session_id, :binary_id
    field :task_id, :binary_id
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [:session_id, :task_id, :type, :path, :is_deliverable, :cleaned_at])
    |> validate_required([:session_id, :type])
    |> validate_inclusion(:type, ["file", "image", "code", "document"])
  end
end
