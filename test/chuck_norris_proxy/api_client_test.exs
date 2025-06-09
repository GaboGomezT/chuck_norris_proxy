defmodule ChuckNorrisProxy.APIClientTest do
  use ExUnit.Case, async: true
  alias ChuckNorrisProxy.APIClient.ResponseTransformer

  describe "ResponseTransformer middleware" do
    test "removes icon_url and url from single joke response" do
      # Mock Tesla.Env with a single joke response
      original_response = %Tesla.Env{
        status: 200,
        body: %{
          "categories" => [],
          "created_at" => "2020-01-05 13:42:19.314155",
          "icon_url" => "https://api.chucknorris.io/img/avatar/chuck-norris.png",
          "id" => "P-vC4QGnRyGg0YvS_U-_Zw",
          "updated_at" => "2020-01-05 13:42:19.314155",
          "url" => "https://api.chucknorris.io/jokes/P-vC4QGnRyGg0YvS_U-_Zw",
          "value" => "Chuck Norris can unscramble an egg."
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the unwanted fields are removed
      refute Map.has_key?(result.body, "icon_url")
      refute Map.has_key?(result.body, "url")

      # Assert the wanted fields remain
      assert result.body["id"] == "P-vC4QGnRyGg0YvS_U-_Zw"
      assert result.body["value"] == "Chuck Norris can unscramble an egg."
      assert result.body["categories"] == []
      assert result.status == 200
    end

    test "removes icon_url and url from each joke in search results" do
      # Mock Tesla.Env with search results response
      original_response = %Tesla.Env{
        status: 200,
        body: %{
          "total" => 2,
          "result" => [
            %{
              "categories" => ["music"],
              "created_at" => "2020-01-05 13:42:19.104863",
              "icon_url" => "https://api.chucknorris.io/img/avatar/chuck-norris.png",
              "id" => "rlra7cwks9y5vqwuzz8osq",
              "updated_at" => "2020-01-05 13:42:19.104863",
              "url" => "https://api.chucknorris.io/jokes/rlra7cwks9y5vqwuzz8osq",
              "value" =>
                "Let the Bodies Hit the Floor was originally written as Chuck Norris' theme song."
            },
            %{
              "categories" => ["dev"],
              "created_at" => "2020-01-05 13:42:20.262289",
              "icon_url" => "https://api.chucknorris.io/img/avatar/chuck-norris.png",
              "id" => "hzPqMKhEQAy6n4f0oMfLXQ",
              "updated_at" => "2020-01-05 13:42:20.262289",
              "url" => "https://api.chucknorris.io/jokes/hzPqMKhEQAy6n4f0oMfLXQ",
              "value" => "Chuck Norris debugs code by staring at it until it confesses."
            }
          ]
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the top-level structure is preserved
      assert result.body["total"] == 2
      assert length(result.body["result"]) == 2
      assert result.status == 200

      # Assert unwanted fields are removed from each joke
      for joke <- result.body["result"] do
        refute Map.has_key?(joke, "icon_url")
        refute Map.has_key?(joke, "url")
        assert Map.has_key?(joke, "id")
        assert Map.has_key?(joke, "value")
        assert Map.has_key?(joke, "categories")
      end

      # Assert specific joke content is preserved
      first_joke = Enum.at(result.body["result"], 0)
      assert first_joke["id"] == "rlra7cwks9y5vqwuzz8osq"
      assert first_joke["categories"] == ["music"]

      second_joke = Enum.at(result.body["result"], 1)
      assert second_joke["id"] == "hzPqMKhEQAy6n4f0oMfLXQ"
      assert second_joke["categories"] == ["dev"]
    end

    test "handles empty search results" do
      # Mock Tesla.Env with empty search results
      original_response = %Tesla.Env{
        status: 200,
        body: %{
          "total" => 0,
          "result" => []
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the response is preserved
      assert result.body["total"] == 0
      assert result.body["result"] == []
      assert result.status == 200
    end

    test "passes through non-200 responses unchanged" do
      # Mock Tesla.Env with error response
      original_response = %Tesla.Env{
        status: 404,
        body: %{
          "error" => "Category not found",
          "icon_url" => "should-not-be-removed",
          "url" => "should-not-be-removed"
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the response is unchanged
      assert result.body == original_response.body
      assert result.status == 404
      assert Map.has_key?(result.body, "icon_url")
      assert Map.has_key?(result.body, "url")
    end

    test "passes through non-map responses unchanged" do
      # Mock Tesla.Env with non-map response (e.g., categories endpoint returns a list)
      original_response = %Tesla.Env{
        status: 200,
        body: ["animal", "career", "celebrity", "dev", "explicit"]
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the response is unchanged
      assert result.body == original_response.body
      assert result.status == 200
    end

    test "passes through error responses from next middleware" do
      # Mock the next middleware chain to return an error
      next_middleware = [{:fn, fn _env -> {:error, :timeout} end}]

      # Call the middleware
      result = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the error is passed through unchanged
      assert result == {:error, :timeout}
    end

    test "handles responses with only icon_url field" do
      # Mock Tesla.Env with response containing only icon_url
      original_response = %Tesla.Env{
        status: 200,
        body: %{
          "id" => "test-id",
          "value" => "test joke",
          "icon_url" => "https://api.chucknorris.io/img/avatar/chuck-norris.png"
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert only icon_url is removed
      refute Map.has_key?(result.body, "icon_url")
      assert result.body["id"] == "test-id"
      assert result.body["value"] == "test joke"
    end

    test "handles responses with only url field" do
      # Mock Tesla.Env with response containing only url
      original_response = %Tesla.Env{
        status: 200,
        body: %{
          "id" => "test-id",
          "value" => "test joke",
          "url" => "https://api.chucknorris.io/jokes/test-id"
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert only url is removed
      refute Map.has_key?(result.body, "url")
      assert result.body["id"] == "test-id"
      assert result.body["value"] == "test joke"
    end

    test "handles responses with neither icon_url nor url fields" do
      # Mock Tesla.Env with response containing neither field
      original_response = %Tesla.Env{
        status: 200,
        body: %{
          "id" => "test-id",
          "value" => "test joke",
          "categories" => ["dev"]
        }
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert the response is unchanged (no fields to remove)
      assert result.body == original_response.body
      assert result.status == 200
    end

    test "preserves all other Tesla.Env fields" do
      # Mock Tesla.Env with additional fields
      original_response = %Tesla.Env{
        method: :get,
        url: "https://api.chucknorris.io/jokes/random",
        query: [],
        headers: [{"content-type", "application/json"}],
        status: 200,
        body: %{
          "id" => "test-id",
          "value" => "test joke",
          "icon_url" => "should-be-removed",
          "url" => "should-be-removed"
        },
        opts: [],
        __module__: Tesla,
        __client__: %Tesla.Client{}
      }

      # Mock the next middleware chain
      next_middleware = [{:fn, fn _env -> {:ok, original_response} end}]

      # Call the middleware
      {:ok, result} = ResponseTransformer.call(%Tesla.Env{}, next_middleware, [])

      # Assert all fields except body are preserved
      assert result.method == original_response.method
      assert result.url == original_response.url
      assert result.query == original_response.query
      assert result.headers == original_response.headers
      assert result.status == original_response.status
      assert result.opts == original_response.opts
      assert result.__module__ == original_response.__module__
      assert result.__client__ == original_response.__client__

      # Assert body is transformed
      refute Map.has_key?(result.body, "icon_url")
      refute Map.has_key?(result.body, "url")
      assert result.body["id"] == "test-id"
      assert result.body["value"] == "test joke"
    end
  end
end
