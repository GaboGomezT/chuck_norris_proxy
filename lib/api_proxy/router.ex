defmodule ApiProxy.Router do
  use Plug.Router

  plug(:match)
  plug(ApiProxy.Plugs.RateLimiter)  # configurable rate limit via RATE_LIMIT env var
  plug(ApiProxy.Plugs.APIKeyAuth)
  plug(:dispatch)

  get "/api-keys-generator" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Path.join(:code.priv_dir(:api_proxy), "static/index.html"))
  end

  post "/api/v1/keys" do
    key = UUID.uuid4()
    ApiProxy.KeysManager.add_key(key)
    send_resp(conn, 200, Jason.encode!(%{key: key}))
  end

  get "/api/v1/joke" do
    send_resp(conn, 200, "Here's a Chuck Norris joke.")
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
