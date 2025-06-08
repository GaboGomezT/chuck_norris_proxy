defmodule ApiProxy.KeysManagerTest do
  use ExUnit.Case, async: false
  alias ApiProxy.KeysManager

  setup do
    # Start a fresh KeysManager for each test
    start_supervised!(KeysManager)
    :ok
  end

  describe "add_key/1" do
    test "adds a key and returns it" do
      key = "test-key-123"
      result = KeysManager.add_key(key)
      assert result == key
    end

    test "different keys are stored separately" do
      key1 = "test-key-1"
      key2 = "test-key-2"

      KeysManager.add_key(key1)
      KeysManager.add_key(key2)

      assert KeysManager.valid_key?(key1) == true
      assert KeysManager.valid_key?(key2) == true
    end
  end

  describe "valid_key?/1" do
    test "returns true for valid keys" do
      key = "valid-key-789"
      KeysManager.add_key(key)
      assert KeysManager.valid_key?(key) == true
    end

    test "returns false for invalid keys" do
      assert KeysManager.valid_key?("non-existent-key") == false
    end

    test "returns false for empty string" do
      assert KeysManager.valid_key?("") == false
    end

    test "returns false for nil" do
      assert KeysManager.valid_key?(nil) == false
    end

    test "keys are case sensitive" do
      key = "CaseSensitiveKey"
      KeysManager.add_key(key)

      assert KeysManager.valid_key?(key) == true
      assert KeysManager.valid_key?(String.downcase(key)) == false
    end
  end

  describe "key hashing" do
    test "keys are stored securely (not in plain text)" do
      key = "secret-key-123"
      KeysManager.add_key(key)

      # Check that the raw key is not directly stored in ETS
      table_contents = :ets.tab2list(:api_keys)

      # The key should be hashed, not stored in plain text
      refute Enum.any?(table_contents, fn {stored_key, _timestamp} ->
               stored_key == key
             end)

      # But the key should still be valid
      assert KeysManager.valid_key?(key) == true
    end
  end
end
