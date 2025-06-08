defmodule ChuckNorrisProxy.Servers.ApiKeyStoreTest do
  use ExUnit.Case, async: false
  alias ChuckNorrisProxy.Servers.ApiKeyStore

  setup do
    # Clear the ETS table for each test (service already running)
    :ets.delete_all_objects(:api_keys)
    :ok
  end

  describe "add_key/1" do
    test "adds a key and returns it" do
      key = "test-key-123"
      result = ApiKeyStore.add_key(key)
      assert result == key
    end

    test "different keys are stored separately" do
      key1 = "test-key-1"
      key2 = "test-key-2"

      ApiKeyStore.add_key(key1)
      ApiKeyStore.add_key(key2)

      assert ApiKeyStore.valid_key?(key1) == true
      assert ApiKeyStore.valid_key?(key2) == true
    end
  end

  describe "valid_key?/1" do
    test "returns true for valid keys" do
      key = "valid-key-789"
      ApiKeyStore.add_key(key)
      assert ApiKeyStore.valid_key?(key) == true
    end

    test "returns false for invalid keys" do
      assert ApiKeyStore.valid_key?("non-existent-key") == false
    end

    test "returns false for empty string" do
      assert ApiKeyStore.valid_key?("") == false
    end

    test "returns false for nil" do
      assert ApiKeyStore.valid_key?(nil) == false
    end

    test "keys are case sensitive" do
      key = "CaseSensitiveKey"
      ApiKeyStore.add_key(key)

      assert ApiKeyStore.valid_key?(key) == true
      assert ApiKeyStore.valid_key?(String.downcase(key)) == false
    end
  end

  describe "key hashing" do
    test "keys are stored securely (not in plain text)" do
      key = "secret-key-123"
      ApiKeyStore.add_key(key)

      # Check that the raw key is not directly stored in ETS
      table_contents = :ets.tab2list(:api_keys)

      # The key should be hashed, not stored in plain text
      refute Enum.any?(table_contents, fn {stored_key, _timestamp} ->
               stored_key == key
             end)

      # But the key should still be valid
      assert ApiKeyStore.valid_key?(key) == true
    end
  end
end
