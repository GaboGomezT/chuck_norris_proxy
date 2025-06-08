ExUnit.start()

# Configure test environment
System.put_env("RATE_LIMIT", "5")  # Use a low limit for testing

# Start the application for integration tests
{:ok, _} = Application.ensure_all_started(:api_proxy)
