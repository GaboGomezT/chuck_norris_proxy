defmodule ApiProxy.Application do
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

    children = [
      # Starts a worker by calling: ApiProxy.Worker.start_link(arg)
      # {ApiProxy.Worker, arg}
      {ApiProxy.Servers.ApiKeyStore, []},
      {ApiProxy.Servers.RateLimiter, []},
      {Plug.Cowboy, scheme: :http, plug: ApiProxy.Router, options: [port: 4000]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApiProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
