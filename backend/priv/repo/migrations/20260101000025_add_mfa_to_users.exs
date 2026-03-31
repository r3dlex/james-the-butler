defmodule James.Repo.Migrations.AddMfaToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :mfa_secret, :text
      add :mfa_enabled, :boolean, default: false
      add :mfa_recovery_codes, {:array, :text}, default: []
      add :webauthn_credentials, :map, default: %{}
    end
  end
end
