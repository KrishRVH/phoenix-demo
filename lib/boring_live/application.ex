defmodule BoringLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        BoringLiveWeb.Telemetry,
        BoringLive.Repo,
        {DNSCluster, query: Application.get_env(:boring_live, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: BoringLive.PubSub},
        # Live viewer tracking (CRDT over PubSub).
        BoringLiveWeb.Presence
      ]
      |> maybe_start_pulse()
      |> Kernel.++([
        # Start to serve requests, typically the last entry.
        BoringLiveWeb.Endpoint
      ])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BoringLive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoringLiveWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_start_pulse(children) do
    if Application.get_env(:boring_live, :start_pulse, true) do
      # Server heartbeat: a supervised process, not a separate worker tier.
      children ++ [BoringLive.Workers.Pulse]
    else
      children
    end
  end
end
