defmodule ApiProxy.Plugs.APIKeyAuthTest do
  use ExUnit.Case, async: false
  use Plug.Test
  alias ApiProxy.Plugs.APIKeyAuth
  alias ApiProxy.KeysManager

  setup do
    # Start KeysManager for each test
    start_supervised!(KeysManager)
    :ok
  end

  describe "init/1" do
    test "returns the options passed to it" do
      opts = [some: :option]
      assert APIKeyAuth.init(opts) == opts
    end

    test "returns empty list for no options" do
      assert APIKeyAuth.init([]) == []
    end
  end

  describe "public endpoints" do
    test "public endpoints work without any headers" do
      public_paths = ["/api-keys-generator", "/api/v1/keys"]

      for path <- public_paths do
        conn =
          conn(:get, path)
          |> APIKeyAuth.call([])

        refute conn.halted
        assert conn.status == 200
      end
    end
  end

  describe "protected endpoints" do
    test "blocks access to /api/v1/joke without API key" do
      conn =
        conn(:get, "/api/v1/joke")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "blocks access to unknown endpoints without API key" do
      conn =
        conn(:get, "/some/protected/endpoint")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 404
      assert conn.resp_body == "Endpoint not found"
    end

    test "allows access with valid API key" do
      # Create a valid API key
      api_key = "test-api-key-123"
      KeysManager.add_key(api_key)

      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("X-API-Key", api_key)
        |> APIKeyAuth.call([])

      refute conn.halted
      assert conn.status == 200
    end

    test "blocks access with invalid API key" do
      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("X-API-Key", "invalid-key")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end
  end

  describe "API key validation" do
    test "validates API key case sensitivity" do
      api_key = "CaseSensitiveKey123"
      KeysManager.add_key(api_key)

      # Correct case should work
      conn1 =
        conn(:get, "/api/v1/joke")
        |> put_req_header("X-API-Key", api_key)
        |> APIKeyAuth.call([])

      refute conn1.halted
      assert conn1.status == 200

      # Wrong case should fail
      conn2 =
        conn(:get, "/api/v1/joke")
        |> put_req_header("X-API-Key", String.downcase(api_key))
        |> APIKeyAuth.call([])

      assert conn2.halted
      assert conn2.status == 401
    end

    test "handles empty API key header" do
      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("X-API-Key", "")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "handles missing API key header" do
      conn =
        conn(:get, "/api/v1/joke")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "handles multiple API key headers (uses first one)" do
      api_key = "valid-key-456"
      KeysManager.add_key(api_key)

      conn =
        conn(:get, "/api/v1/joke")
        |> put_req_header("X-API-Key", api_key)
        |> put_req_header("X-API-Key", "invalid-key")
        |> APIKeyAuth.call([])

      refute conn.halted
    end
  end

  describe "different HTTP methods" do
    test "protects POST requests without API key" do
      conn =
        conn(:post, "/api/v1/joke")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "allows POST requests with valid API key" do
      api_key = "test-post-key"
      KeysManager.add_key(api_key)

      conn =
        conn(:post, "/api/v1/joke")
        |> put_req_header("X-API-Key", api_key)
        |> APIKeyAuth.call([])

      refute conn.halted
      assert conn.status != 401
    end

    test "protects PUT requests without API key" do
      conn =
        conn(:put, "/api/v1/joke")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "allows PUT requests with valid API key" do
      api_key = "test-put-key"
      KeysManager.add_key(api_key)

      conn =
        conn(:put, "/api/v1/joke")
        |> put_req_header("X-API-Key", api_key)
        |> APIKeyAuth.call([])

      refute conn.halted
      assert conn.status != 401
    end

    test "protects DELETE requests without API key" do
      conn =
        conn(:delete, "/api/v1/joke")
        |> APIKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "allows DELETE requests with valid API key" do
      api_key = "test-delete-key"
      KeysManager.add_key(api_key)

      conn =
        conn(:delete, "/api/v1/joke")
        |> put_req_header("X-API-Key", api_key)
        |> APIKeyAuth.call([])

      refute conn.halted
      assert conn.status != 401
    end
  end

end
