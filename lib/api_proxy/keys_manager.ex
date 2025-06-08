defmodule ApiProxy.KeysManager do
  @table_name :api_keys

  def start_link do
    :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, self()}
  end

  def add_key(key) do
    hashed_key = :crypto.hash(:sha256, key)
    :ets.insert(@table_name, {hashed_key, System.system_time(:second)})
    key
  end

  def valid_key?(key) do
    hashed_key = :crypto.hash(:sha256, key)
    :ets.member(@table_name, hashed_key)
  end
end
