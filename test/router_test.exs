defmodule ChuckNorrisProxy.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  import ChuckNorrisProxy.Test.EnvHelper
  alias ChuckNorrisProxy.Router

  @opts Router.init([])

  setup do
    # Clear ETS tables for each test (services already running)
    :ets.delete_all_objects(:api_keys)
    :ets.delete_all_objects(:rate_limiter)
    :ok
  end

  describe "GET /docs" do
    test "serves the HTML page" do
      conn =
        conn(:get, "/docs")
        |> Router.call(@opts)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      assert String.contains?(conn.resp_body, "Chuck Norris API Documentation")
    end

    test "does not require authentication" do
      conn =
        conn(:get, "/docs")
        |> Router.call(@opts)

      assert conn.status == 200
      refute conn.halted
    end
  end

  describe "POST /api/v1/keys" do
    test "generates a new API key" do
      conn =
        conn(:post, "/api/v1/keys")
        |> Router.call(@opts)

      assert conn.status == 200

      # Parse JSON response
      {:ok, response} = Jason.decode(conn.resp_body)
      assert Map.has_key?(response, "key")
      assert is_binary(response["key"])
      assert String.length(response["key"]) > 0
    end

    test "generated key is valid for authentication" do
      # Generate a key
      conn =
        conn(:post, "/api/v1/keys")
        |> Router.call(@opts)

      {:ok, response} = Jason.decode(conn.resp_body)
      api_key = response["key"]

      # Use the key to access protected endpoint
      protected_conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("x-api-key", api_key)
        |> Router.call(@opts)

      assert protected_conn.status == 200
    end

    test "does not require authentication" do
      conn =
        conn(:post, "/api/v1/keys")
        |> Router.call(@opts)

      assert conn.status == 200
      refute conn.halted
    end

    test "each call generates a unique key" do
      conn1 = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      conn2 = conn(:post, "/api/v1/keys") |> Router.call(@opts)

      {:ok, response1} = Jason.decode(conn1.resp_body)
      {:ok, response2} = Jason.decode(conn2.resp_body)

      assert response1["key"] != response2["key"]
    end
  end

  describe "GET /api/v1/joke" do
    test "requires authentication" do
      conn =
        conn(:get, "/api/v1/joke")
        |> Router.call(@opts)

      assert conn.status == 401
      assert conn.resp_body == Jason.encode!(%{message: "Unauthorized"})
    end

    test "returns joke with valid API key" do
      # Generate API key
      key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      {:ok, response} = Jason.decode(key_conn.resp_body)
      api_key = response["key"]

      # Use API key to get joke
      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("x-api-key", api_key)
        |> Router.call(@opts)

      assert conn.status == 200

      # The response should match our mock data
      {:ok, expected} = ChuckNorrisProxy.Test.MockAPIClient.get_random_joke()
      assert conn.resp_body == Jason.encode!(expected.body)
    end

    test "includes rate limit headers" do
      # Generate API key
      key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      {:ok, response} = Jason.decode(key_conn.resp_body)
      api_key = response["key"]

      # Make request
      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("x-api-key", api_key)
        |> put_req_header("x-forwarded-for", "192.168.1.100")
        |> Router.call(@opts)

      assert conn.status == 200
      assert get_resp_header(conn, "x-ratelimit-limit") != []
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
      assert get_resp_header(conn, "x-ratelimit-reset") != []
    end

    test "enforces rate limiting" do
      with_env("RATE_LIMIT", "1", fn ->
        # Generate API key
        key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
        {:ok, response} = Jason.decode(key_conn.resp_body)
        api_key = response["key"]

        # First request should succeed
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.101")
          |> Router.call(@opts)

        assert conn1.status == 200

        # Second request should be rate limited
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.101")
          |> Router.call(@opts)

        assert conn2.status == 429
        {:ok, error_response} = Jason.decode(conn2.resp_body)
        assert error_response["error"] == "Rate limit exceeded"
      end)
    end
  end

  describe "GET /api/v1/joke/:category" do
    test "returns joke in category with valid API key" do
      # Generate API key
      key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      {:ok, response} = Jason.decode(key_conn.resp_body)
      api_key = response["key"]

      # Use API key to get joke in category
      conn =
        conn(:get, "/api/v1/joke/dev")
        |> put_req_header("x-api-key", api_key)
        |> Router.call(@opts)

      assert conn.status == 200

      # The response should match our mock data
      {:ok, expected} = ChuckNorrisProxy.Test.MockAPIClient.get_random_joke_by_category("dev")
      assert conn.resp_body == Jason.encode!(expected.body)
    end

    test "requires authentication" do
      conn =
        conn(:get, "/api/v1/joke/dev")
        |> Router.call(@opts)

      assert conn.status == 401
      assert conn.resp_body == Jason.encode!(%{message: "Unauthorized"})
    end
  end

  describe "GET /api/v1/categories" do
    test "returns categories with valid API key" do
      # Generate API key
      key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      {:ok, response} = Jason.decode(key_conn.resp_body)
      api_key = response["key"]

      # Use API key to get categories
      conn =
        conn(:get, "/api/v1/categories")
        |> put_req_header("x-api-key", api_key)
        |> Router.call(@opts)

      assert conn.status == 200

      # The response should match our mock data
      {:ok, expected} = ChuckNorrisProxy.Test.MockAPIClient.get_categories()
      assert conn.resp_body == Jason.encode!(expected.body)
    end

    test "requires authentication" do
      conn =
        conn(:get, "/api/v1/categories")
        |> Router.call(@opts)

      assert conn.status == 401
      assert conn.resp_body == Jason.encode!(%{message: "Unauthorized"})
    end
  end

  describe "GET /api/v1/search" do
    test "returns search results with valid API key" do
      # Generate API key
      key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      {:ok, response} = Jason.decode(key_conn.resp_body)
      api_key = response["key"]

      # Use API key to search jokes
      conn =
        conn(:get, "/api/v1/search?query=test")
        |> put_req_header("x-api-key", api_key)
        |> Router.call(@opts)

      assert conn.status == 200

      # The response should match our mock data
      {:ok, expected} = ChuckNorrisProxy.Test.MockAPIClient.search_jokes("test")
      assert conn.resp_body == Jason.encode!(expected.body)
    end

    test "requires query parameter" do
      # Generate API key
      key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
      {:ok, response} = Jason.decode(key_conn.resp_body)
      api_key = response["key"]

      # Try to search without query
      conn =
        conn(:get, "/api/v1/search")
        |> put_req_header("x-api-key", api_key)
        |> Router.call(@opts)

      assert conn.status == 400
      assert conn.resp_body == Jason.encode!(%{error: "Query parameter is required"})
    end

    test "requires authentication" do
      conn =
        conn(:get, "/api/v1/search?query=test")
        |> Router.call(@opts)

      assert conn.status == 401
      assert conn.resp_body == Jason.encode!(%{message: "Unauthorized"})
    end
  end

  describe "integration flow" do
    test "complete user flow: generate key -> use key -> get rate limited" do
      with_env("RATE_LIMIT", "2", fn ->
        # Step 1: Generate API key
        key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
        assert key_conn.status == 200
        {:ok, response} = Jason.decode(key_conn.resp_body)
        api_key = response["key"]

        # Step 2: Use key successfully (first request)
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.200")
          |> Router.call(@opts)

        assert conn1.status == 200

        assert conn1.resp_body ==
                 Jason.encode!(%{
                   categories: [],
                   created_at: "2020-01-05 13:42:19.314155",
                   id: "P-vC4QGnRyGg0YvS_U-_Zw",
                   updated_at: "2020-01-05 13:42:19.314155",
                   value: "Chuck Norris can unscramble an egg."
                 })

        # Step 3: Use key successfully (second request)
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.200")
          |> Router.call(@opts)

        assert conn2.status == 200

        # Step 4: Get rate limited (third request)
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.200")
          |> Router.call(@opts)

        assert conn3.status == 429
        {:ok, error_response} = Jason.decode(conn3.resp_body)
        assert error_response["error"] == "Rate limit exceeded"
      end)
    end

    test "different IPs have independent rate limits" do
      with_env("RATE_LIMIT", "1", fn ->
        # Generate API key
        key_conn = conn(:post, "/api/v1/keys") |> Router.call(@opts)
        {:ok, response} = Jason.decode(key_conn.resp_body)
        api_key = response["key"]

        # IP 1 uses up its limit
        conn1 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.201")
          |> Router.call(@opts)

        assert conn1.status == 200

        # IP 1 gets rate limited
        conn2 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.201")
          |> Router.call(@opts)

        assert conn2.status == 429

        # IP 2 can still make requests
        conn3 =
          conn(:get, "/api/v1/joke")
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("x-forwarded-for", "192.168.1.202")
          |> Router.call(@opts)

        assert conn3.status == 200
      end)
    end
  end

  describe "error handling" do
    test "handles malformed requests gracefully" do
      conn =
        conn(:get, "/api/v1/joke")
        |> Router.call(@opts)

      assert conn.status == 401
    end
  end
end
