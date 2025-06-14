defmodule ChuckNorrisProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :chuck_norris_proxy,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ChuckNorrisProxy.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:plug, "~> 1.15"},
      # for JSON responses
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:envy, "~> 1.1.1"},
      {:tesla, "~> 1.8"},
      # HTTP client adapter for Tesla
      {:hackney, "~> 1.18"}
    ]
  end
end
