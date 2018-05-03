defmodule GbaLoaderWeb.Router do
  use GbaLoaderWeb, :router

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

  scope "/", GbaLoaderWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/loader", PageController, :loader
    post "/upload", PageController, :upload

  end
end
