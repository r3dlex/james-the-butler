defmodule James.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text
      add :email, :citext, null: false
      add :oauth_provider, :text
      add :oauth_uid, :text
      add :mfa_secret, :text
      add :mfa_method, :text
      # Soft FK to personality_profiles — avoids circular FK constraint
      add :personality_id, :binary_id
      add :execution_mode, :text, default: "direct"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:oauth_provider, :oauth_uid])
  end
end
