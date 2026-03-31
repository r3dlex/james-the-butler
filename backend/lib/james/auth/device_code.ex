defmodule James.Auth.DeviceCode do
  @moduledoc """
  Device code auth flow for clients that can't do browser-based OAuth
  (Office add-ins, Chrome extension, mobile app).

  Flow:
  1. Client calls POST /api/auth/device-code → gets {device_code, user_code, verification_uri}
  2. User opens verification_uri in browser, enters user_code
  3. Client polls POST /api/auth/device-code/token with device_code
  4. Once approved, client receives JWT tokens
  """

  alias James.Repo

  @code_ttl_seconds 600
  @poll_interval_seconds 5

  defmodule PendingCode do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "device_codes" do
      field :device_code, :string
      field :user_code, :string
      field :user_id, :binary_id
      field :status, :string, default: "pending"
      field :expires_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    def changeset(code, attrs) do
      code
      |> cast(attrs, [:device_code, :user_code, :user_id, :status, :expires_at])
      |> validate_required([:device_code, :user_code, :expires_at])
      |> validate_inclusion(:status, ~w[pending approved denied expired])
    end
  end

  @doc "Generate a new device code pair."
  def generate_code do
    device_code = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    user_code = generate_user_code()
    expires_at = DateTime.add(DateTime.utc_now(), @code_ttl_seconds, :second)

    %PendingCode{}
    |> PendingCode.changeset(%{
      device_code: device_code,
      user_code: user_code,
      expires_at: expires_at
    })
    |> Repo.insert()
    |> case do
      {:ok, code} ->
        {:ok,
         %{
           device_code: code.device_code,
           user_code: code.user_code,
           expires_in: @code_ttl_seconds,
           interval: @poll_interval_seconds
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc "Verify a user code and bind it to a user."
  def verify_code(user_code, user_id) do
    import Ecto.Query

    case Repo.one(
           from c in PendingCode,
             where:
               c.user_code == ^user_code and c.status == "pending" and
                 c.expires_at > ^DateTime.utc_now()
         ) do
      nil ->
        {:error, :invalid_or_expired}

      code ->
        code
        |> PendingCode.changeset(%{user_id: user_id, status: "approved"})
        |> Repo.update()
    end
  end

  @doc "Check if a device code has been approved. Returns {:ok, user_id} or {:pending | :expired | :denied}."
  def check_code(device_code) do
    import Ecto.Query

    case Repo.one(from c in PendingCode, where: c.device_code == ^device_code) do
      nil ->
        {:error, :not_found}

      %{status: "approved", user_id: user_id} ->
        {:ok, user_id}

      %{status: "pending", expires_at: expires_at} ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          {:error, :expired}
        else
          {:error, :pending}
        end

      %{status: status} ->
        {:error, String.to_atom(status)}
    end
  end

  defp generate_user_code do
    # 6-character alphanumeric code (uppercase, no ambiguous chars)
    chars = ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    Enum.map_join(1..6, fn _ -> Enum.random(chars) end)
  end
end
