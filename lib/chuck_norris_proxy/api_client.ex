defmodule ChuckNorrisProxy.APIClient do
  defmodule ResponseTransformer do
    @behaviour Tesla.Middleware

    @impl Tesla.Middleware
    def call(env, next, _opts) do
      env
      |> Tesla.run(next)
      |> case do
        {:ok, %{status: status, body: body} = response_env}
        when status in 200..299 and is_map(body) ->
          transformed_body = transform_response_body(body)
          {:ok, %{response_env | body: transformed_body}}

        other ->
          other
      end
    end

    defp transform_response_body(body) when is_map(body) do
      body
      |> Map.drop(["icon_url", "url"])
      |> case do
        %{"result" => results} = response when is_list(results) ->
          # Handle search results - transform each joke in the result array
          transformed_results = Enum.map(results, &Map.drop(&1, ["icon_url", "url"]))
          %{response | "result" => transformed_results}

        response ->
          # Handle single joke response or other responses
          response
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
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Logger, log_level: &log_level/1}
    ]

    # Add retry middleware in non-test environments
    middleware =
      if System.get_env("MIX_ENV") != "test" do
        middleware ++
          [
            {Tesla.Middleware.Retry,
             delay: 500,
             max_retries: 3,
             max_delay: 4_000,
             should_retry: fn
               {:ok, %{status: status}} when status in 500..599 -> true
               {:ok, _} -> false
               {:error, _} -> true
             end}
          ]
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

  defp log_level(%{status: status}) when status in 500..599, do: :error
  defp log_level(%{status: status}) when status in 400..499, do: :warn
  defp log_level(_), do: :info
end
