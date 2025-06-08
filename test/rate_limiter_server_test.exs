defmodule ApiProxy.RateLimiterServerTest do
  use ExUnit.Case, async: false
  alias ApiProxy.RateLimiterServer

  setup do
    # Start a fresh RateLimiterServer for each test
    start_supervised!(RateLimiterServer)
    :ok
  end

  describe "get_request_count/1" do
    test "returns 0 for new keys" do
      key = {"127.0.0.1", 1234567890}
      assert RateLimiterServer.get_request_count(key) == 0
    end

    test "returns correct count after increments" do
      key = {"192.168.1.1", 1234567890}

      # Initial count should be 0
      assert RateLimiterServer.get_request_count(key) == 0

      # After one increment
      RateLimiterServer.increment_request_count(key)
      assert RateLimiterServer.get_request_count(key) == 1

      # After multiple increments
      RateLimiterServer.increment_request_count(key)
      RateLimiterServer.increment_request_count(key)
      assert RateLimiterServer.get_request_count(key) == 3
    end
  end

    test "handles multiple different keys independently" do
      key1 = {"192.168.1.1", 1234567890}
      key2 = {"192.168.1.2", 1234567890}

      RateLimiterServer.increment_request_count(key1)
      RateLimiterServer.increment_request_count(key1)
      RateLimiterServer.increment_request_count(key2)

      assert RateLimiterServer.get_request_count(key1) == 2
      assert RateLimiterServer.get_request_count(key2) == 1
    end

    test "handles same IP with different hours" do
      ip = "192.168.1.1"
      hour1 = 1234567890
      hour2 = 1234571490  # Different hour

      key1 = {ip, hour1}
      key2 = {ip, hour2}

      RateLimiterServer.increment_request_count(key1)
      RateLimiterServer.increment_request_count(key1)
      RateLimiterServer.increment_request_count(key2)

      assert RateLimiterServer.get_request_count(key1) == 2
      assert RateLimiterServer.get_request_count(key2) == 1
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
  end

  describe "edge cases" do
    test "handles large request counts" do
      key = {"heavy-user", 1234567890}

      # Make many requests
      for _i <- 1..1000 do
        RateLimiterServer.increment_request_count(key)
      end

      assert RateLimiterServer.get_request_count(key) == 1000
    end

    test "handles complex IP addresses" do
      ipv4_key = {"192.168.1.100", 1234567890}
      ipv6_key = {"2001:0db8:85a3:0000:0000:8a2e:0370:7334", 1234567890}

      RateLimiterServer.increment_request_count(ipv4_key)
      RateLimiterServer.increment_request_count(ipv6_key)

      assert RateLimiterServer.get_request_count(ipv4_key) == 1
      assert RateLimiterServer.get_request_count(ipv6_key) == 1
    end
  end
end
