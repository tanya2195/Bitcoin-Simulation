defmodule Bitcoin1Web.Router do
  use Bitcoin1Web, :router

  pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Bitcoin1Web do
    pipe_through :browser

    get "/", PageController, :index
    get "/bitcoinBtc", BitcoinController, :showBtc
    get "/bitcoinHash", BitcoinController, :showHash
    get "/bitcoinTx", BitcoinController, :showTx
    get "/bitcoinTxList", BitcoinController, :showTxList
    resources "/bitcoin", BitcoinController


  end

  # Other scopes may use custom stacks.
  # scope "/api", Bitcoin1Web do
  #   pipe_through :api
  # end
end
