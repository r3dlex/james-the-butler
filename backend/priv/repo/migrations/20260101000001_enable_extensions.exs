defmodule James.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\""
    execute "CREATE EXTENSION IF NOT EXISTS \"vector\""
  end

  def down do
    execute "DROP EXTENSION IF EXISTS \"vector\""
    execute "DROP EXTENSION IF EXISTS \"citext\""
    execute "DROP EXTENSION IF EXISTS \"pgcrypto\""
  end
end
