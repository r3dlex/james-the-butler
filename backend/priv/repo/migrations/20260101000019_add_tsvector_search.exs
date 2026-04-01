defmodule James.Repo.Migrations.AddTsvectorSearch do
  use Ecto.Migration

  def up do
    # Add tsvector columns for full-text search
    alter table(:sessions) do
      add :search_vector, :tsvector
    end

    alter table(:messages) do
      add :search_vector, :tsvector
    end

    # Create GIN indexes for fast full-text search
    create index(:sessions, [:search_vector], using: :gin)
    create index(:messages, [:search_vector], using: :gin)

    # Create triggers to auto-update tsvector on insert/update
    execute """
    CREATE OR REPLACE FUNCTION sessions_search_vector_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', coalesce(NEW.name, ''));
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER sessions_search_vector_update
    BEFORE INSERT OR UPDATE OF name ON sessions
    FOR EACH ROW EXECUTE FUNCTION sessions_search_vector_trigger();
    """

    execute """
    CREATE OR REPLACE FUNCTION messages_search_vector_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', coalesce(NEW.content, ''));
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER messages_search_vector_update
    BEFORE INSERT OR UPDATE OF content ON messages
    FOR EACH ROW EXECUTE FUNCTION messages_search_vector_trigger();
    """

    # Backfill existing records
    execute "UPDATE sessions SET search_vector = to_tsvector('english', coalesce(name, ''));"
    execute "UPDATE messages SET search_vector = to_tsvector('english', coalesce(content, ''));"
  end

  def down do
    execute "DROP TRIGGER IF EXISTS messages_search_vector_update ON messages;"
    execute "DROP FUNCTION IF EXISTS messages_search_vector_trigger();"
    execute "DROP TRIGGER IF EXISTS sessions_search_vector_update ON sessions;"
    execute "DROP FUNCTION IF EXISTS sessions_search_vector_trigger();"

    alter table(:messages) do
      remove :search_vector
    end

    alter table(:sessions) do
      remove :search_vector
    end
  end
end
