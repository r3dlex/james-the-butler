defmodule James.Repo.Migrations.UpgradeMessagesInsertedAtToUsec do
  use Ecto.Migration

  def up do
    alter table(:messages) do
      modify :inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end
  end

  def down do
    alter table(:messages) do
      modify :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end
  end
end
