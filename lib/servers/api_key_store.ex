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
    Logger.info("API key store started with ETS table: #{@table_name}")
    {:ok, %{}}
  end

  def add_key(key) do
    hashed_key = :crypto.hash(:sha256, key)
    :ets.insert(@table_name, {hashed_key, System.system_time(:second)})
    Logger.info("New API key added to store")
    key
  end

  def valid_key?(key) when is_binary(key) do
    hashed_key = :crypto.hash(:sha256, key)
    is_valid = :ets.member(@table_name, hashed_key)
    Logger.debug("API key validation attempt: #{if is_valid, do: "valid", else: "invalid"}")
    is_valid
  end

  def valid_key?(_key) do
    Logger.debug("Invalid API key format received")
    false
  end
end
