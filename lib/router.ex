defmodule ChuckNorrisProxy.Router do
  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:fetch_query_params)
  # configurable rate limit via RATE_LIMIT env var
  plug(ChuckNorrisProxy.Plugs.RateLimiter)
  plug(ChuckNorrisProxy.Plugs.APIKeyAuth)
  plug(:dispatch)

  get "/docs" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Path.join(:code.priv_dir(:chuck_norris_proxy), "static/index.html"))
  end

  post "/api/v1/keys" do
    key = UUID.uuid4()
    ChuckNorrisProxy.Servers.ApiKeyStore.add_key(key)
    send_resp(conn, 200, Jason.encode!(%{key: key}))
  end

  # Get a random joke
  get "/api/v1/joke" do
    case ChuckNorrisProxy.APIClient.get_random_joke() do
      {:ok, %{status: 200, body: joke}} ->
        send_resp(conn, 200, Jason.encode!(joke))

      {:error, _} ->
        send_resp(conn, 500, Jason.encode!(%{error: "Failed to fetch joke"}))
    end
  end

  # Get a random joke by category
  get "/api/v1/joke/:category" do
    case ChuckNorrisProxy.APIClient.get_random_joke_by_category(category) do
      {:ok, %{status: 200, body: joke}} ->
        send_resp(conn, 200, Jason.encode!(joke))

      {:ok, %{status: 404}} ->
        send_resp(conn, 404, Jason.encode!(%{error: "Category not found"}))

      {:error, _} ->
        send_resp(conn, 500, Jason.encode!(%{error: "Failed to fetch joke"}))
    end
  end

  # Get all categories
  get "/api/v1/categories" do
    case ChuckNorrisProxy.APIClient.get_categories() do
      {:ok, %{status: 200, body: categories}} ->
        send_resp(conn, 200, Jason.encode!(categories))

      {:error, _} ->
        send_resp(conn, 500, Jason.encode!(%{error: "Failed to fetch categories"}))
    end
  end

  # Search jokes
  get "/api/v1/search" do
    query = conn.query_params["query"]

    if is_nil(query) or query == "" do
      send_resp(conn, 400, Jason.encode!(%{error: "Query parameter is required"}))
    else
      case ChuckNorrisProxy.APIClient.search_jokes(query) do
        {:ok, %{status: 200, body: results}} ->
          send_resp(conn, 200, Jason.encode!(results))

        {:error, _} ->
          send_resp(conn, 500, Jason.encode!(%{error: "Failed to search jokes"}))
      end
    end
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{message: "Endpoint not found"}))
  end
end
