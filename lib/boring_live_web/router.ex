defmodule BoringLiveWeb.Router do
  use BoringLiveWeb, :router

  @secure_browser_headers %{
    "content-security-policy" =>
      "base-uri 'self'; connect-src 'self' ws: wss:; default-src 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BoringLiveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @secure_browser_headers
  end

  get "/healthz", BoringLiveWeb.HealthController, :healthz
  get "/readyz", BoringLiveWeb.HealthController, :readyz

  scope "/", BoringLiveWeb do
    pipe_through :browser

    live "/", TodoLive
  end
end
