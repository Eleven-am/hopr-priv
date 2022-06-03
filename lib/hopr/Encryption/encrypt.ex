defmodule Hopr.Encrypt do
  @moduledoc """
   This is the encryption model
   It provides ways to generate arbitrary keys that can be used
   It also and interface for encrypting and decrypting data
  """

  @block_size 16
  @secret_key "5b4f9d23-e3f0-4725-ba74-12f68e123b7e"

  @doc """
    Generates a random key from multiple segments of strings
    length:  The length of the segments
    segment: The number of segments
  """
  @spec generateKey(integer, integer) :: String
  def generateKey(length, segment) do
    case length do
      0 -> ""
      1 -> makeId(segment)
      x -> generateKey(x - 1, segment) <> "-" <> makeId(segment)
    end
  end

  @doc """
    Encrypt the given `data` with AES-256 in CBC mode using `key` and `iv`
    PKCS#7 padding will be added to `data`
  """
  @spec encrypt(String, String) :: String
  def encrypt(term, secret \\ @secret_key) do
    secret_key_hash = make_hash(secret, 32)
    iv = :crypto.strong_rand_bytes(@block_size)

    plain_text = Jason.encode!(term)
    padded_text = pad_pkcs7(plain_text, @block_size)
    encrypted_text = :crypto.crypto_one_time(:aes_256_cbc, secret_key_hash, iv, padded_text, true)

    encrypted_text = iv <> encrypted_text
    Base.encode64(encrypted_text)
  end

  @doc """
  Decrypt the given `data` with AES-256 in CBC mode using `key` and `iv`
  PKCS#7 padding will be removed
  """
  @spec decrypt(String, String) :: String
  def decrypt(plain_text, secret \\ @secret_key) do
    secret_key_hash = make_hash(secret, 32)

    case Base.decode64(plain_text) do
      {:ok, ciphertext} ->
        <<iv::binary-16, ciphertext::binary>> = ciphertext
        decrypted_text = :crypto.crypto_one_time(:aes_256_cbc, secret_key_hash, iv, ciphertext, false)

        data = unpad_pkcs7(decrypted_text)
               |> Jason.decode!()
        {:ok, data}
      _ -> {:error, "Something went wrong"}
    end
  end

  @doc "Generates a uuid for the given context"
  @spec generateUUID() :: String
  def generateUUID do
    s = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    n = :os.system_time(:millisecond)
    val = generateUUID(s, n)
    String.downcase(val)
  end

  defp pad_pkcs7(message, blocksize) do
    pad = blocksize - rem(byte_size(message), blocksize)
    message <> to_string(List.duplicate(pad, pad))
  end

  defp unpad_pkcs7(data) do
    <<pad>> = binary_part(data, byte_size(data), -1)
    binary_part(data, 0, byte_size(data) - pad)
  end

  defp make_hash(text, length) do
    :crypto.hash(:sha256, text)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  defp generateUUID(string, number) do
    val =
      (number + :rand.uniform(16))
      |> rem(16)
      |> Bitwise.bor(0)

    newVal =
      Float.floor(number / 16)
      |> trunc()

    case string do
      "" ->
        ""

      "4" <> rest ->
        "4" <> generateUUID(rest, number)

      "-" <> rest ->
        "-" <> generateUUID(rest, number)

      "x" <> rest ->
        Integer.to_string(val, 16) <> generateUUID(rest, newVal)

      "y" <> rest ->
        temp =
          Bitwise.band(val, 0x3)
          |> Bitwise.bor(0x8)

        Integer.to_string(temp, 16) <> generateUUID(rest, newVal)
    end
  end

  defp makeId(id) do
    alphabets = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    for _ <- 1..id, into: "", do: <<Enum.random(alphabets)>>
  end

end