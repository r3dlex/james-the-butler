defmodule James.Providers.Crypto do
  @moduledoc """
  AES-256-GCM encryption/decryption for sensitive provider credentials
  such as API keys and OAuth tokens.

  The encryption key is derived from the `:encryption_key` app config, falling
  back to `:jwt_secret` when no dedicated key is set. The key is always
  stretched/truncated to exactly 32 bytes so it is suitable for AES-256.
  """

  @aad "james_provider_v1"

  @doc """
  Encrypts `plaintext` using AES-256-GCM.

  Returns `{ciphertext_with_tag, iv}` where both are binaries, or `nil` when
  `plaintext` is `nil` (pass-through for local providers that need no key).
  """
  @spec encrypt(String.t() | nil) :: {binary(), binary()} | nil
  def encrypt(nil), do: nil

  def encrypt(plaintext) when is_binary(plaintext) do
    iv = :crypto.strong_rand_bytes(12)
    key = derived_key()
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)
    # Prepend the 16-byte GCM tag to the ciphertext so we can verify integrity
    {tag <> ciphertext, iv}
  end

  @doc """
  Decrypts `encrypted` (produced by `encrypt/1`) using the given `iv`.

  Returns `{:ok, plaintext}` on success or `{:error, :decryption_failed}` when
  the ciphertext has been tampered with or the key does not match.
  """
  @spec decrypt(binary(), binary()) :: {:ok, String.t()} | {:error, :decryption_failed}
  def decrypt(encrypted, iv) when is_binary(encrypted) and is_binary(iv) do
    key = derived_key()

    try do
      <<tag::binary-16, ciphertext::binary>> = encrypted

      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        :error -> {:error, :decryption_failed}
      end
    rescue
      _ -> {:error, :decryption_failed}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp derived_key do
    raw =
      Application.get_env(:james, :encryption_key) ||
        Application.get_env(:james, :jwt_secret, "default-dev-key-change-me-in-prod")

    # Ensure exactly 32 bytes for AES-256 using SHA-256 derivation
    :crypto.hash(:sha256, raw)
  end
end
