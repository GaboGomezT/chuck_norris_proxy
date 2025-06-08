defmodule ApiProxy.Plugs.RateLimiter do
  import Plug.Conn
  require Logger

  # Default: 100 requests per hour
  @default_limit 100

  def init(opts) do
    # We'll read the limit at runtime, so just pass through the options
    opts
  end

  def call(conn, opts) do
    # Read limit from environment at runtime, with fallback to options, then default
    limit =
      System.get_env("RATE_LIMIT", "#{@default_limit}")
      |> String.to_integer()
      |> then(fn env_limit -> Keyword.get(opts, :limit, env_limit) end)

    # Only rate limit the /api/v1/joke endpoint
    case conn.request_path do
      "/api/v1/joke" ->
        client_ip = get_client_ip(conn)
        current_hour = get_current_hour()
        key = {client_ip, current_hour}

        current_count = ApiProxy.Servers.RateLimiter.get_request_count(key)

        case current_count do
          count when count >= limit ->
            conn
            |> put_resp_header("x-ratelimit-limit", Integer.to_string(limit))
            |> put_resp_header("x-ratelimit-remaining", "0")
            |> put_resp_header("x-ratelimit-reset", Integer.to_string(current_hour + 3600))
            |> send_resp(
              429,
              Jason.encode!(%{
                error: "Rate limit exceeded",
                message: "You have exceeded the rate limit of #{limit} requests per hour",
                retry_after: 3600 - rem(:os.system_time(:second), 3600)
              })
            )
            |> halt()

          count ->
            ApiProxy.Servers.RateLimiter.increment_request_count(key)
            remaining = max(0, limit - count - 1)

            conn
            |> put_resp_header("x-ratelimit-limit", Integer.to_string(limit))
            |> put_resp_header("x-ratelimit-remaining", Integer.to_string(remaining))
            |> put_resp_header("x-ratelimit-reset", Integer.to_string(current_hour + 3600))
        end

      _ ->
        # For all other endpoints, pass through without rate limiting
        conn
    end
  end

  defp get_client_ip(conn) do
    # Check for forwarded headers first (for load balancers/proxies)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [real_ip | _] ->
            real_ip

          [] ->
            conn.remote_ip
            |> :inet.ntoa()
            |> to_string()
        end
    end
  end

  defp get_current_hour do
    # Get current timestamp rounded down to the hour
    :os.system_time(:second)
    |> div(3600)
    |> Kernel.*(3600)
  end
end
