defmodule BoringLive.Repo do
  use Ecto.Repo,
    otp_app: :boring_live,
    adapter: Ecto.Adapters.Postgres
end
