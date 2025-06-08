defmodule ChuckNorrisProxyTest do
  use ExUnit.Case
  import ChuckNorrisProxy.Test.EnvHelper

  describe "Application startup" do
    test "application starts successfully" do
      # The application should already be started by test_helper.exs
      assert Process.whereis(ChuckNorrisProxy.Servers.ApiKeyStore) != nil
      assert Process.whereis(ChuckNorrisProxy.Servers.RateLimiter) != nil
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

    test "environment helper works correctly" do
      original_value = System.get_env("RATE_LIMIT")

      with_env("RATE_LIMIT", "999", fn ->
        assert System.get_env("RATE_LIMIT") == "999"
      end)

      # Should be restored
      assert System.get_env("RATE_LIMIT") == original_value
    end

    test "environment helper works with unset variables" do
      without_env("NONEXISTENT_VAR", fn ->
        assert System.get_env("NONEXISTENT_VAR") == nil
      end)
    end
  end
end
