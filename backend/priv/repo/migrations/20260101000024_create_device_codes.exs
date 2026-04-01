defmodule James.Repo.Migrations.CreateDeviceCodes do
  use Ecto.Migration

  def change do
    create table(:device_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :device_code, :text, null: false
      add :user_code, :text, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :status, :text, default: "pending", null: false
      add :expires_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_codes, [:device_code])
    create unique_index(:device_codes, [:user_code])
  end
end
