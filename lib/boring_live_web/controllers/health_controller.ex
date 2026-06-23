defmodule BoringLiveWeb.HealthController do
  use BoringLiveWeb, :controller

  def healthz(conn, _params), do: text(conn, "ok")

  def readyz(conn, _params) do
    case BoringLive.Repo.query("select 1", [], timeout: 2_000) do
      {:ok, _result} ->
        text(conn, "ready")

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> text("unavailable")
    end
  end
end
