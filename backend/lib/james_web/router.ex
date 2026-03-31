defmodule JamesWeb.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug :accepts, ["json"]
    plug JamesWeb.Plugs.Auth
  end

  # Public endpoints
  scope "/", JamesWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", JamesWeb do
    pipe_through :api

    # Auth (public)
    post "/auth/dev_login", AuthController, :dev_login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/device-code", AuthController, :device_code
    post "/auth/device-code/token", AuthController, :device_code_token

    # OAuth 2.0 — browser-based redirect flow
    get "/auth/:provider", AuthController, :oauth_redirect
    get "/auth/:provider/callback", AuthController, :oauth_callback
  end

  scope "/api", JamesWeb do
    pipe_through :authenticated

    # Auth (protected)
    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
    post "/auth/device-code/verify", AuthController, :device_code_verify

    # Sessions
    get "/sessions", SessionController, :index
    post "/sessions", SessionController, :create
    get "/sessions/:id", SessionController, :show
    put "/sessions/:id", SessionController, :update
    delete "/sessions/:id", SessionController, :delete
    post "/sessions/:id/messages", SessionController, :send_message

    # Projects
    get "/projects", ProjectController, :index
    post "/projects", ProjectController, :create
    get "/projects/:id", ProjectController, :show
    put "/projects/:id", ProjectController, :update
    delete "/projects/:id", ProjectController, :delete

    # Tasks
    get "/tasks", TaskController, :index
    get "/tasks/:id", TaskController, :show
    post "/tasks/:id/approve", TaskController, :approve
    post "/tasks/:id/reject", TaskController, :reject

    # Hosts
    get "/hosts", HostController, :index
    get "/hosts/:id", HostController, :show
    get "/hosts/:id/sessions", HostController, :sessions

    # Memory
    get "/memories", MemoryController, :index
    put "/memories/:id", MemoryController, :update
    delete "/memories/:id", MemoryController, :delete

    # Token usage
    get "/tokens/usage", TokenController, :usage
    get "/tokens/usage/summary", TokenController, :summary

    # Search
    get "/search", SearchController, :index

    # Embeddings
    post "/embeddings", EmbeddingController, :create

    # Plugins
    resources "/plugins", PluginController, only: [:index, :create, :delete]
    post "/plugins/:id/enable", PluginController, :enable
    post "/plugins/:id/disable", PluginController, :disable

    # Hooks
    resources "/hooks", HookController, only: [:index, :create, :update, :delete]

    # Channel configs
    resources "/channel-configs", ChannelConfigController, only: [:index, :create, :delete]
  end
end
