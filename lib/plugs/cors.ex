defmodule ChuckNorrisProxy.Plugs.CORS do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-API-Key")
    |> put_resp_header("access-control-max-age", "86400")
    |> handle_options(conn.method)
  end

  defp handle_options(conn, "OPTIONS") do
    conn
    |> send_resp(204, "")
    |> halt()
  end

  defp handle_options(conn, _method), do: conn
end
