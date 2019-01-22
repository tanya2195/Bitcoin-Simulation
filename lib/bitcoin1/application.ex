defmodule Bitcoin1.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      Bitcoin1.Repo,
      Bitcoin1Web.Endpoint,
      {Bitcoin1.Btcmain, ["100", "80"]} 
    ]
    opts = [strategy: :one_for_one, name: Bitcoin1.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Bitcoin1Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
