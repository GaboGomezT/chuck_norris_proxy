defmodule ApiProxy.Router do
  use Plug.Router

  plug(:match)
  plug ApiProxy.Plugs.APIKeyAuth
  plug(:dispatch)

  get "/joke" do
    send_resp(conn, 200, "Here's a Chuck Norris joke.")
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
