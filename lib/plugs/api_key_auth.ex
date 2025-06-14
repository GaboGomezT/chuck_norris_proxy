defmodule ChuckNorrisProxy.Plugs.APIKeyAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip auth for public endpoints
    if public_path?(conn.request_path) do
      conn
    else
      case get_req_header(conn, "x-api-key") do
        [key | _] when is_binary(key) and key != "" ->
          if ChuckNorrisProxy.Servers.ApiKeyStore.valid_key?(key) do
            conn
          else
            conn
            |> send_resp(401, Jason.encode!(%{message: "Unauthorized"}))
            |> halt()
          end

        _ ->
          conn
          |> send_resp(401, Jason.encode!(%{message: "Unauthorized"}))
          |> halt()
      end
    end
  end

  # List of paths that don't require authentication
  defp public_path?(path) do
    path in ["/docs", "/api/v1/keys"]
  end
end
