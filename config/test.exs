import Config

config :chuck_norris_proxy,
  api_client: ChuckNorrisProxy.Test.MockAPIClient

config :logger,
  level: :none,
  backends: []
