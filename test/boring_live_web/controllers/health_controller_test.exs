defmodule BoringLiveWeb.HealthControllerTest do
  use BoringLiveWeb.ConnCase, async: true

  test "GET /healthz returns liveness", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert text_response(conn, 200) == "ok"
  end

  test "GET /readyz checks database readiness", %{conn: conn} do
    conn = get(conn, ~p"/readyz")

    assert text_response(conn, 200) == "ready"
  end
end
