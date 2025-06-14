defmodule ChuckNorrisProxy.Servers.ApiKeyStore do
  use GenServer
  require Logger
  @table_name :api_keys

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table])

    unless System.get_env("MIX_ENV") == "test" do
      Logger.info("API key store started with ETS table: #{@table_name}")
    end

    {:ok, %{}}
  end

  def add_key(key) do
    hashed_key = :crypto.hash(:sha256, key)
    :ets.insert(@table_name, {hashed_key, System.system_time(:second)})

    unless System.get_env("MIX_ENV") == "test" do
      Logger.info("New API key added to store")
    end

    key
  end

  def valid_key?(key) when is_binary(key) do
    hashed_key = :crypto.hash(:sha256, key)
    is_valid = :ets.member(@table_name, hashed_key)

    unless System.get_env("MIX_ENV") == "test" do
      Logger.debug("API key validation attempt: #{if is_valid, do: "valid", else: "invalid"}")
    end

    is_valid
  end

  def valid_key?(_key) do
    unless System.get_env("MIX_ENV") == "test" do
      Logger.debug("Invalid API key format received")
    end

    false
  end
end
