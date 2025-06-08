import Config

config :chuck_norris_proxy,
  api_client: ChuckNorrisProxy.Test.MockAPIClient

config :tesla,
  disable_deprecated_builder_warning: true

config :logger,
  level: :none,
  backends: [],
  compile_time_purge_matching: [
    [level_lower_than: :error]
  ]

# Silence all logger calls
config :logger, :console,
  level: :none,
  format: ""
