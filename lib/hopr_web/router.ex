defmodule HoprWeb.Router do
  use HoprWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  get "/", HoprWeb.DeveloperController, :index

  scope "/api", HoprWeb do
    pipe_through :api

    post "/users", DeveloperController, :createUser
    post "/applications", DeveloperController, :createApplication
    post "/rooms", DeveloperController, :createRoom
    post "/auth/refresh", DeveloperController, :authRefresh
    post "/auth/access", DeveloperController, :authAccess

    get "/users/:apiKey", DeveloperController, :getUser
    get "/applications/:clientId/:clientSecret", DeveloperController, :getApplication
    get "/rooms/:authKey/:clientId/:name", DeveloperController, :getRoom
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: HoprWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
