defmodule ChuckNorrisProxy.Test.MockAPIClient do
  @moduledoc """
  Mock implementation of the Chuck Norris API client for testing.
  """

  def get_random_joke do
    {:ok,
     %{
       status: 200,
       body: %{
         categories: [],
         created_at: "2020-01-05 13:42:19.314155",
         id: "P-vC4QGnRyGg0YvS_U-_Zw",
         updated_at: "2020-01-05 13:42:19.314155",
         value: "Chuck Norris can unscramble an egg."
       }
     }}
  end

  def get_random_joke_by_category(category) do
    {:ok,
     %{
       status: 200,
       body: %{
         categories: [category],
         created_at: "2020-01-05 13:42:19.314155",
         id: "P-vC4QGnRyGg0YvS_U-_Zw",
         updated_at: "2020-01-05 13:42:19.314155",
         value: "Chuck Norris can unscramble an egg in #{category}."
       }
     }}
  end

  def get_categories do
    {:ok,
     %{
       status: 200,
       body: ["animal", "career", "celebrity", "dev", "explicit", "fashion", "food", "history", "money", "movie", "music", "political", "religion", "science", "sport", "travel"]
     }}
  end

  def search_jokes(query) do
    {:ok,
     %{
       status: 200,
       body: %{
         total: 1,
         result: [
           %{
             categories: [],
             created_at: "2020-01-05 13:42:19.314155",
             id: "P-vC4QGnRyGg0YvS_U-_Zw",
             updated_at: "2020-01-05 13:42:19.314155",
             value: "Chuck Norris can search for #{query}."
           }
         ]
       }
     }}
  end
end
