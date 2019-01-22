defmodule Bitcoin1.Repo do
  use Ecto.Repo,
    otp_app: :bitcoin1,
    adapter: Ecto.Adapters.Postgres

  # def conf do
  #   parse_url Application.get_env(:phoenix, :database)[:url]
  # end

  # def priv do
  #   app_dir(:bitcoin1, "priv/repo")
  # end

end
