defmodule James.Repo.Migrations.AddWorkingFileTypeToArtifacts do
  use Ecto.Migration

  def change do
    # No schema change needed; the type column already stores arbitrary text.
    # This migration is a no-op placeholder that documents the addition of
    # "working_file" and "deliverable" as recognised artifact type values.
    :ok
  end
end
