defmodule Bitcoin1Web.PageController do
  use Bitcoin1Web, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
