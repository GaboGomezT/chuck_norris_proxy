# Silence all logging as early as possible
Logger.configure(level: :none)
Logger.remove_backend(:console)

# Ensure applications started during tests also use silent logging
Application.put_env(:logger, :level, :none)
Application.put_env(:logger, :backends, [])

ExUnit.start()

# Load test support files
Code.require_file("support/env_helper.ex", __DIR__)
Code.require_file("support/mock_api_client.ex", __DIR__)

# Set the API client configuration at runtime for tests
Application.put_env(:chuck_norris_proxy, :api_client, ChuckNorrisProxy.Test.MockAPIClient)
