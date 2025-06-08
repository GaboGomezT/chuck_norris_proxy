defmodule ApiProxyTest do
  use ExUnit.Case
  doctest ApiProxy

  describe "ApiProxy module" do
    test "greets the world" do
      assert ApiProxy.hello() == :world
    end

    test "module exists and is accessible" do
      assert Code.ensure_loaded?(ApiProxy)
    end
  end

  describe "Application startup" do
    test "application starts successfully" do
      # The application should already be started by test_helper.exs
      assert Process.whereis(ApiProxy.KeysManager) != nil
      assert Process.whereis(ApiProxy.RateLimiterServer) != nil
    end

    test "ETS tables are created" do
      # Check that required ETS tables exist
      assert :ets.info(:api_keys) != :undefined
      assert :ets.info(:rate_limiter) != :undefined
    end
  end

  describe "Environment configuration" do
    test "RATE_LIMIT environment variable is set for tests" do
      rate_limit = System.get_env("RATE_LIMIT")
      assert rate_limit != nil
      assert String.to_integer(rate_limit) > 0
    end
  end
end
