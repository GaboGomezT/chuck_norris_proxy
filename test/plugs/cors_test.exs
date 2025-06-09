defmodule ChuckNorrisProxy.Plugs.CORSTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  alias ChuckNorrisProxy.Plugs.CORS

  describe "CORS headers" do
    test "adds CORS headers to all responses" do
      conn =
        conn(:get, "/api/v1/joke")
        |> CORS.call([])

      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, OPTIONS"]
      assert get_resp_header(conn, "access-control-allow-headers") == ["Content-Type, Authorization, X-API-Key"]
      assert get_resp_header(conn, "access-control-max-age") == ["86400"]
    end

    test "handles OPTIONS requests" do
      conn =
        conn(:options, "/api/v1/joke")
        |> CORS.call([])

      assert conn.status == 204
      assert conn.resp_body == ""
      assert conn.halted
    end

    test "allows actual requests to proceed" do
      conn =
        conn(:get, "/api/v1/joke")
        |> CORS.call([])

      refute conn.halted
    end
  end
end
