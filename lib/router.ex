defmodule ApiProxy.Router do
  use Plug.Router

  plug(:match)
  # configurable rate limit via RATE_LIMIT env var
  plug(ApiProxy.Plugs.RateLimiter)
  plug(ApiProxy.Plugs.APIKeyAuth)
  plug(:dispatch)

  get "/api-keys-generator" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Path.join(:code.priv_dir(:api_proxy), "static/index.html"))
  end

  post "/api/v1/keys" do
    key = UUID.uuid4()
    ApiProxy.Servers.ApiKeyStore.add_key(key)
    send_resp(conn, 200, Jason.encode!(%{key: key}))
  end

  get "/api/v1/joke" do
    send_resp(
      conn,
      200,
      Jason.encode!(%{
        categories: [],
        created_at: "2020-01-05 13:42:19.314155",
        id: "P-vC4QGnRyGg0YvS_U-_Zw",
        updated_at: "2020-01-05 13:42:19.314155",
        value: "Chuck Norris can unscramble an egg."
      })
    )
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{message: "Endpoint not found"}))
  end
end
