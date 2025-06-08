defmodule ApiProxy.Plugs.APIKeyAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip auth for public endpoints
    if public_path?(conn.request_path) do
      conn
    else
      case get_req_header(conn, "x-api-key") do
        [key | _] when is_binary(key) and key != "" ->
          if ApiProxy.KeysManager.valid_key?(key) do
            conn
          else
            conn
            |> send_resp(401, "Unauthorized")
            |> halt()
          end

        _ ->
          conn
          |> send_resp(401, "Unauthorized")
          |> halt()
      end
    end
  end

  # List of paths that don't require authentication
  defp public_path?(path) do
    path in ["/api-keys-generator", "/api/v1/keys"]
  end
end
