defmodule ChuckNorrisProxy.Plugs.RateLimiterTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  import ChuckNorrisProxy.Test.EnvHelper
  alias ChuckNorrisProxy.Plugs.RateLimiter

  setup do
    # Clear the ETS table for each test (service already running)
    :ets.delete_all_objects(:rate_limiter)
    :ok
  end

  describe "init/1" do
    test "returns the options passed to it" do
      opts = [limit: 10]
      assert RateLimiter.init(opts) == opts
    end

    test "returns empty list for no options" do
      assert RateLimiter.init([]) == []
    end
  end

  describe "environment variable configuration" do
    test "reads RATE_LIMIT from environment" do
      with_env("RATE_LIMIT", "2", fn ->
        conn =
          conn(:get, "/api/v1/joke")
          |> RateLimiter.call([])

        # First request should pass
        refute conn.halted
        assert get_resp_header(conn, "x-ratelimit-limit") == ["2"]

        # Make second request
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "127.0.0.1")
          |> RateLimiter.call([])

        refute conn2.halted
        assert get_resp_header(conn2, "x-ratelimit-limit") == ["2"]

        # Third request should be rate limited
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "127.0.0.1")
          |> RateLimiter.call([])

        assert conn3.halted
        assert conn3.status == 429
        assert get_resp_header(conn3, "x-ratelimit-limit") == ["2"]
      end)
    end

    test "uses default when RATE_LIMIT environment variable is not set" do
      without_env("RATE_LIMIT", fn ->
        conn =
          conn(:get, "/api/v1/joke")
          |> RateLimiter.call([])

        # Should use default limit of 100
        assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]
      end)
    end
  end

  describe "rate limiting logic" do
    test "allows requests under the limit" do
      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("x-forwarded-for", "192.168.1.100")
        |> RateLimiter.call([])

      refute conn.halted

      assert get_resp_header(conn, "x-ratelimit-remaining") |> List.first() |> String.to_integer() >=
               0
    end

    test "blocks requests over the limit" do
      with_env("RATE_LIMIT", "1", fn ->
        # First request should pass
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "192.168.1.101")
          |> RateLimiter.call([])

        refute conn1.halted

        # Second request should be blocked
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "192.168.1.101")
          |> RateLimiter.call([])

        assert conn2.halted
        assert conn2.status == 429

        # Verify rate limit headers
        assert get_resp_header(conn2, "x-ratelimit-limit") == ["1"]
        assert get_resp_header(conn2, "x-ratelimit-remaining") == ["0"]

        # Verify JSON error response
        {:ok, response} = Jason.decode(conn2.resp_body)
        assert response["error"] == "Rate limit exceeded"
        assert response["message"] == "You have exceeded the rate limit of 1 requests per hour"
        assert is_integer(response["retry_after"])
      end)
    end

    test "rate limits are per IP address" do
      with_env("RATE_LIMIT", "1", fn ->
        # First IP makes a request
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "192.168.1.200")
          |> RateLimiter.call([])

        refute conn1.halted

        # Different IP can still make requests
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "192.168.1.201")
          |> RateLimiter.call([])

        refute conn2.halted

        # First IP is now blocked
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "192.168.1.200")
          |> RateLimiter.call([])

        assert conn3.halted
        assert conn3.status == 429
      end)
    end
  end

  describe "IP address extraction" do
    test "extracts IP from x-forwarded-for header and applies rate limiting per IP" do
      with_env("RATE_LIMIT", "1", fn ->
        # First request with forwarded IP - should succeed
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "203.0.113.1, 192.168.1.1")
          |> RateLimiter.call([])

        refute conn1.halted
        assert conn1.status != 429

        # Second request with same forwarded IP - should be rate limited
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "203.0.113.1, 192.168.1.1")
          |> RateLimiter.call([])

        assert conn2.halted
        assert conn2.status == 429

        # Request with different forwarded IP - should succeed
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "203.0.113.2, 192.168.1.1")
          |> RateLimiter.call([])

        refute conn3.halted
        assert conn3.status != 429
      end)
    end

    test "extracts IP from x-real-ip header when x-forwarded-for is not present" do
      with_env("RATE_LIMIT", "1", fn ->
        # First request with real-ip header - should succeed
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-real-ip", "203.0.113.10")
          |> RateLimiter.call([])

        refute conn1.halted

        # Second request with same real-ip - should be rate limited
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-real-ip", "203.0.113.10")
          |> RateLimiter.call([])

        assert conn2.halted
        assert conn2.status == 429

        # Request with different real-ip - should succeed
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-real-ip", "203.0.113.11")
          |> RateLimiter.call([])

        refute conn3.halted
      end)
    end

    test "uses remote_ip when no forwarded headers are present" do
      with_env("RATE_LIMIT", "1", fn ->
        # First request using remote_ip - should succeed
        conn1 =
          conn(:get, "/api/v1/joke")
          |> RateLimiter.call([])

        refute conn1.halted

        # Second request using same remote_ip - should be rate limited
        # Note: Plug.Test always uses {127, 0, 0, 1} as remote_ip
        conn2 =
          conn(:get, "/api/v1/joke")
          |> RateLimiter.call([])

        assert conn2.halted
        assert conn2.status == 429
      end)
    end

    test "x-forwarded-for takes precedence over x-real-ip" do
      with_env("RATE_LIMIT", "1", fn ->
        # Request with both headers - should use x-forwarded-for
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "203.0.113.20")
          |> put_req_header("x-real-ip", "203.0.113.21")
          |> RateLimiter.call([])

        refute conn1.halted

        # Same x-forwarded-for should be rate limited
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-forwarded-for", "203.0.113.20")
          |> put_req_header("x-real-ip", "203.0.113.21")
          |> RateLimiter.call([])

        assert conn2.halted

        # Request with only x-real-ip (different IP) should succeed
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-real-ip", "203.0.113.21")
          |> RateLimiter.call([])

        refute conn3.halted
      end)
    end
  end

  describe "endpoint filtering" do
    test "only rate limits /api/v1/joke endpoint" do
      # These endpoints should not be rate limited
      non_rate_limited_paths = [
        "/api-keys-generator",
        "/api/v1/keys",
        "/some-other-path",
        "/"
      ]

      for path <- non_rate_limited_paths do
        conn =
          conn(:get, path)
          |> RateLimiter.call([])

        refute conn.halted
        assert get_resp_header(conn, "x-ratelimit-limit") == []
      end
    end

    test "rate limits /api/v1/joke endpoint" do
      conn =
        conn(:get, "/api/v1/joke")
        |> RateLimiter.call([])

      # Should have rate limit headers even if not blocked
      assert get_resp_header(conn, "x-ratelimit-limit") != []
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
      assert get_resp_header(conn, "x-ratelimit-reset") != []

      # Verify header values are valid integers
      limit = get_resp_header(conn, "x-ratelimit-limit") |> List.first() |> String.to_integer()

      remaining =
        get_resp_header(conn, "x-ratelimit-remaining") |> List.first() |> String.to_integer()

      reset = get_resp_header(conn, "x-ratelimit-reset") |> List.first() |> String.to_integer()

      assert limit > 0
      assert remaining >= 0
      assert reset > 0
    end
  end
end
