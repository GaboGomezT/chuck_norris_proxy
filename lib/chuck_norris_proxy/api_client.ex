defmodule ChuckNorrisProxy.APIClient do
  defmodule ResponseTransformer do
    @behaviour Tesla.Middleware

    @impl Tesla.Middleware
    def call(env, next, _opts) do
      env
      |> Tesla.run(next)
      |> case do
        {:ok, %{status: status, body: body} = response_env} when status in 200..299 and is_map(body) ->
          transformed_body = Map.drop(body, ["icon_url", "url"])
          {:ok, %{response_env | body: transformed_body}}
        other -> other
      end
    end
  end

  defp api_client do
    Application.get_env(:chuck_norris_proxy, :api_client, __MODULE__)
  end

  defp tesla_client do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.chucknorris.io"},
      ResponseTransformer,
      Tesla.Middleware.JSON
    ]

    # Only add Logger middleware outside of test environment
    middleware = if Mix.env() != :test do
      middleware ++ [Tesla.Middleware.Logger]
    else
      middleware
    end

    Tesla.client(middleware)
  end

  def get_random_joke do
    if api_client() == __MODULE__ do
      Tesla.get(tesla_client(), "/jokes/random")
    else
      api_client().get_random_joke()
    end
  end

  def get_random_joke_by_category(category) do
    if api_client() == __MODULE__ do
      Tesla.get(tesla_client(), "/jokes/random?category=#{category}")
    else
      api_client().get_random_joke_by_category(category)
    end
  end

  def get_categories do
    if api_client() == __MODULE__ do
      Tesla.get(tesla_client(), "/jokes/categories")
    else
      api_client().get_categories()
    end
  end

  def search_jokes(query) do
    if api_client() == __MODULE__ do
      Tesla.get(tesla_client(), "/jokes/search?query=#{query}")
    else
      api_client().search_jokes(query)
    end
  end
end
