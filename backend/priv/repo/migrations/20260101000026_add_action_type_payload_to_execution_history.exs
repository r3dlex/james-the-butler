defmodule James.Repo.Migrations.AddActionTypePayloadToExecutionHistory do
  use Ecto.Migration

  def change do
    alter table(:execution_history) do
      add :action_type, :text
      add :payload, :map
    end
  end
end
