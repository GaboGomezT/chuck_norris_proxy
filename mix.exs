defmodule ApiProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :api_proxy,
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
      mod: {ApiProxy.Application, []}
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
      {:dotenv, "~> 3.0.0"}
    ]
  end
end
