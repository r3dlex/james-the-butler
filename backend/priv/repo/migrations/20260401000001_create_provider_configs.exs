defmodule James.Repo.Migrations.CreateProviderConfigs do
  use Ecto.Migration

  def change do
    create table(:provider_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :host_id, references(:hosts, type: :binary_id, on_delete: :nilify_all)
      add :provider_type, :text, null: false
      add :display_name, :text, null: false
      add :api_key_encrypted, :binary
      add :api_key_iv, :binary
      add :base_url, :text
      add :auth_method, :text, null: false, default: "api_key"
      add :status, :text, null: false, default: "untested"
      add :last_tested_at, :utc_datetime_usec
      add :oauth_token_encrypted, :binary
      add :oauth_refresh_token_encrypted, :binary

      timestamps(type: :utc_datetime)
    end

    create index(:provider_configs, [:user_id])
  end
end
