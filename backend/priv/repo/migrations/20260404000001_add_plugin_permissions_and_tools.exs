defmodule James.Repo.Migrations.AddPluginPermissionsAndTools do
  use Ecto.Migration

  def change do
    alter table(:plugins) do
      add :code_path, :text
      add :permissions, :map, default: %{}
      add :installed_at, :utc_datetime
      add :last_active_at, :utc_datetime
    end
  end
end
