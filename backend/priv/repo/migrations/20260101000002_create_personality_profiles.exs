defmodule James.Repo.Migrations.CreatePersonalityProfiles do
  use Ecto.Migration

  def change do
    create table(:personality_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      # user_id FK added after users table exists (see migration 20260101000004)
      add :user_id, :binary_id, null: false
      add :preset, :text
      add :custom_prompt, :text

      timestamps(type: :utc_datetime)
    end
  end
end
