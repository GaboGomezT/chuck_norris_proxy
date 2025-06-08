defmodule ChuckNorrisProxy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Load .env file if it exists (dev and test only)
    unless Mix.env() == :prod do
      Envy.auto_load()
    end

    # Base children that always start
    base_children = [
      {ChuckNorrisProxy.Servers.ApiKeyStore, []},
      {ChuckNorrisProxy.Servers.RateLimiter, []}
    ]

    # Only start the web server if not in test environment
    children = if Mix.env() != :test do
      base_children ++ [{Plug.Cowboy, scheme: :http, plug: ChuckNorrisProxy.Router, options: [port: 4000]}]
    else
      base_children
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChuckNorrisProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
