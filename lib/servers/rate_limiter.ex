defmodule ApiProxy.Servers.RateLimiter do
  use GenServer
  require Logger

  @table_name :rate_limiter

  def start_link(_opts) do
    Logger.info("Starting rate limiter server")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_request_count(key) do
    count = case :ets.lookup(@table_name, key) do
      [{^key, count}] -> count
      [] -> 0
    end
    Logger.debug("Current request count for key: #{inspect(key)} = #{count}")
    count
  end

  def increment_request_count(key) do
    new_count = :ets.update_counter(@table_name, key, {2, 1}, {key, 0})
    Logger.debug("Incremented request count for key: #{inspect(key)} to #{new_count}")
    new_count
  end

  # GenServer callbacks

  @impl true
  def init(_args) do
    # Create the ETS table owned by this GenServer process
    :ets.new(@table_name, [:set, :public, :named_table])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("Rate limiter server initialized with ETS table: #{@table_name}")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.info("Starting rate limiter cleanup cycle")
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Schedule cleanup every hour
    Process.send_after(self(), :cleanup, 3600 * 1000)
    Logger.debug("Scheduled next rate limiter cleanup in 1 hour")
  end

  defp cleanup_old_entries do
    current_hour = get_current_hour()
    # Remove entries older than 2 hours
    cutoff_time = current_hour - 7200

    Logger.debug("Cleaning up rate limiter entries older than #{DateTime.from_unix!(cutoff_time)}")

    deleted_count =
      :ets.select_delete(@table_name, [
        {{{:_, :"$1"}, :_}, [{:<, :"$1", cutoff_time}], [true]}
      ])

    Logger.info("Rate limiter cleanup completed, deleted #{deleted_count} old entries")
  end

  defp get_current_hour do
    # Get current timestamp rounded down to the hour
    :os.system_time(:second)
    |> div(3600)
    |> Kernel.*(3600)
  end
end
