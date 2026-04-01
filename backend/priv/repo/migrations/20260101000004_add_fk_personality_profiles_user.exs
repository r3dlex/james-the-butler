defmodule James.Repo.Migrations.AddFkPersonalityProfilesUser do
  use Ecto.Migration

  def change do
    alter table(:personality_profiles) do
      modify :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create index(:personality_profiles, [:user_id])
  end
end
