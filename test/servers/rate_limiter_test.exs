defmodule ChuckNorrisProxy.Servers.RateLimiterTest do
  use ExUnit.Case, async: false
  alias ChuckNorrisProxy.Servers.RateLimiter

  setup do
    # Clear the ETS table for each test (service already running)
    :ets.delete_all_objects(:rate_limiter)
    :ok
  end

  describe "get_request_count/1" do
    test "returns 0 for new keys" do
      key = {"127.0.0.1", 1_234_567_890}
      assert RateLimiter.get_request_count(key) == 0
    end

    test "returns correct count after increments" do
      key = {"192.168.1.1", 1_234_567_890}

      # Initial count should be 0
      assert RateLimiter.get_request_count(key) == 0

      # After one increment
      RateLimiter.increment_request_count(key)
      assert RateLimiter.get_request_count(key) == 1

      # After multiple increments
      RateLimiter.increment_request_count(key)
      RateLimiter.increment_request_count(key)
      assert RateLimiter.get_request_count(key) == 3
    end
  end

  describe "increment_request_count/1" do
    test "increments count from 0 to 1" do
      key = {"10.0.0.1", 1_234_567_890}

      result = RateLimiter.increment_request_count(key)
      assert result == 1
      assert RateLimiter.get_request_count(key) == 1
    end

    test "increments existing count" do
      key = {"10.0.0.2", 1_234_567_890}

      # First increment
      RateLimiter.increment_request_count(key)

      # Second increment
      result = RateLimiter.increment_request_count(key)
      assert result == 2
      assert RateLimiter.get_request_count(key) == 2
    end

    test "handles multiple different keys independently" do
      key1 = {"192.168.1.1", 1_234_567_890}
      key2 = {"192.168.1.2", 1_234_567_890}

      RateLimiter.increment_request_count(key1)
      RateLimiter.increment_request_count(key1)
      RateLimiter.increment_request_count(key2)

      assert RateLimiter.get_request_count(key1) == 2
      assert RateLimiter.get_request_count(key2) == 1
    end

    test "handles same IP with different hours" do
      ip = "192.168.1.1"
      hour1 = 1_234_567_890
      # Different hour
      hour2 = 1_234_571_490

      key1 = {ip, hour1}
      key2 = {ip, hour2}

      RateLimiter.increment_request_count(key1)
      RateLimiter.increment_request_count(key1)
      RateLimiter.increment_request_count(key2)

      assert RateLimiter.get_request_count(key1) == 2
      assert RateLimiter.get_request_count(key2) == 1
    end
  end

  describe "ETS table operations" do
    test "creates and manages ETS table correctly" do
      # The table should exist and be accessible
      info = :ets.info(:rate_limiter)
      assert info != :undefined
      assert info[:type] == :set
      assert info[:protection] == :public
    end

    test "ETS table persists data correctly" do
      key = {"test-ip", 1_234_567_890}

      # Insert data via the server
      RateLimiter.increment_request_count(key)

      # Verify data exists in ETS directly
      result = :ets.lookup(:rate_limiter, key)
      assert result == [{key, 1}]
    end
  end
end
