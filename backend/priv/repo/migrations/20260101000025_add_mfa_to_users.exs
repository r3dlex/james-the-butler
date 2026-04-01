defmodule James.Repo.Migrations.AddMfaToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # mfa_secret and mfa_method were already added in the create_users migration
      add :mfa_enabled, :boolean, default: false
      add :mfa_recovery_codes, {:array, :text}, default: []
      add :webauthn_credentials, :map, default: %{}
    end
  end
end
