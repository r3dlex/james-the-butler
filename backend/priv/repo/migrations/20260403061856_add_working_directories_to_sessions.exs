defmodule James.Repo.Migrations.AddWorkingDirectoriesToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :working_directories, {:array, :string}, default: []
    end
  end
end
