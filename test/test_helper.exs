ExUnit.start()

# Configure test environment
# Use a low limit for testing
System.put_env("RATE_LIMIT", "5")

# Start the application for integration tests
{:ok, _} = Application.ensure_all_started(:api_proxy)
