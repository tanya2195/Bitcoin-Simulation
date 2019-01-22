# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :bitcoin1,
  ecto_repos: [Bitcoin1.Repo]

# Configures the endpoint
config :bitcoin1, Bitcoin1Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "/jIFsjMVtgaB3903JDOlQeCFBgomq/S57krSgysEzWkH/eaOf79w18GzB6MAPWID",
  render_errors: [view: Bitcoin1Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Bitcoin1.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
