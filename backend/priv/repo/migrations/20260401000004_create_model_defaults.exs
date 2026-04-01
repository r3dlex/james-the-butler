defmodule James.Repo.Migrations.CreateModelDefaults do
  use Ecto.Migration

  def change do
    create table(:model_defaults, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :host_id, references(:hosts, type: :binary_id, on_delete: :delete_all), null: false

      add :agent_type, :string, null: false

      add :provider_config_id,
          references(:provider_configs, type: :binary_id, on_delete: :delete_all),
          null: false

      add :model_name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:model_defaults, [:user_id])
    create index(:model_defaults, [:user_id, :host_id])

    create unique_index(:model_defaults, [:user_id, :host_id, :agent_type],
             name: :model_defaults_user_host_agent_type_index
           )
  end
end
