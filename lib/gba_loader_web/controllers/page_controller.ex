defmodule GbaLoaderWeb.PageController do
  use GbaLoaderWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def upload(conn, params) do
    filename = params["upload"]["upload"].path
    GbaLoader.run(filename)
    render conn, "index.html"
  end

  def loader(conn, _params) do
    render conn, "loader.html"
  end
end
