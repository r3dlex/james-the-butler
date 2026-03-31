defmodule James.Repo.Migrations.CreateHosts do
  use Ecto.Migration

  def change do
    create table(:hosts, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :endpoint, :text
      add :status, :text, default: "offline"
      add :is_primary, :boolean, default: false
      add :mtls_cert_fingerprint, :text

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :last_seen_at, :utc_datetime
    end
  end
end
