defmodule James.Providers.CryptoTest do
  use ExUnit.Case, async: true

  alias James.Providers.Crypto

  describe "encrypt/1 + decrypt/2 round-trip" do
    test "encrypts and decrypts a normal API key" do
      plaintext = "sk-ant-api03-some-real-key"
      {encrypted, iv} = Crypto.encrypt(plaintext)
      assert {:ok, ^plaintext} = Crypto.decrypt(encrypted, iv)
    end

    test "different plaintexts produce different ciphertexts" do
      {enc1, _iv1} = Crypto.encrypt("key-aaa")
      {enc2, _iv2} = Crypto.encrypt("key-bbb")
      refute enc1 == enc2
    end

    test "same plaintext encrypted twice produces different ciphertexts (random IV)" do
      {enc1, iv1} = Crypto.encrypt("same-key")
      {enc2, iv2} = Crypto.encrypt("same-key")
      # IVs should differ (random per call)
      refute iv1 == iv2
      # Ciphertexts will also differ due to the unique IV
      refute enc1 == enc2
    end

    test "tampered ciphertext returns {:error, :decryption_failed}" do
      {encrypted, iv} = Crypto.encrypt("valid-key")
      tampered = :crypto.strong_rand_bytes(byte_size(encrypted))
      assert {:error, :decryption_failed} = Crypto.decrypt(tampered, iv)
    end

    test "nil input returns nil (passthrough for local providers)" do
      assert Crypto.encrypt(nil) == nil
    end

    test "empty string encrypts and decrypts correctly" do
      plaintext = ""
      {encrypted, iv} = Crypto.encrypt(plaintext)
      assert {:ok, ^plaintext} = Crypto.decrypt(encrypted, iv)
    end
  end
end
