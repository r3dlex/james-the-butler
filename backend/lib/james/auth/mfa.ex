defmodule James.Auth.MFA do
  @moduledoc """
  Multi-factor authentication: TOTP (RFC 6238) and recovery codes.
  WebAuthn scaffold for hardware keys (requires wax_ dep in Phase 7).
  """

  import Bitwise

  def generate_secret do
    secret = :crypto.strong_rand_bytes(20) |> Base.encode32(padding: false)
    %{secret: secret}
  end

  def verify_totp(secret, code) do
    time_step = div(System.os_time(:second), 30)

    Enum.any?(-1..1, fn offset ->
      expected = generate_totp(secret, time_step + offset)
      Plug.Crypto.secure_compare(expected, code)
    end)
  end

  def generate_recovery_codes(count \\ 8) do
    Enum.map(1..count, fn _ ->
      :crypto.strong_rand_bytes(5) |> Base.encode32(padding: false) |> String.downcase()
    end)
  end

  def verify_recovery_code(stored_codes, code) do
    if code in stored_codes do
      {:ok, List.delete(stored_codes, code)}
    else
      {:error, :invalid_code}
    end
  end

  defp generate_totp(secret, time_step) do
    key = Base.decode32!(secret, padding: false)
    msg = <<time_step::unsigned-big-integer-size(64)>>
    hmac = :crypto.mac(:hmac, :sha, key, msg)
    offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F
    <<_::binary-size(offset), code::unsigned-big-integer-size(32), _::binary>> = hmac
    truncated = (code &&& 0x7FFFFFFF) |> rem(1_000_000)
    truncated |> Integer.to_string() |> String.pad_leading(6, "0")
  end
end
