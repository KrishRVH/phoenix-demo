defmodule BoringLiveWeb.TodoLiveTest do
  use BoringLiveWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BoringLive.Todos

  test "renders the surface", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Boring LiveView"
    assert html =~ "Open this in two tabs"
    assert html =~ "viewing"
    assert html =~ "pulse waiting"
  end

  test "adding a task updates the list, stats, and activity feed", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    submit_task(view, "Write one honest test")

    assert has_element?(view, "#todos", "Write one honest test")
    assert has_element?(view, "#events", "created")
    assert view |> element("#total-stat") |> render() =~ "1"
    assert view |> element("#active-stat") |> render() =~ "1"
  end

  test "blank input is rejected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = submit_task(view, "   ")

    assert html =~ "blank"
    refute has_element?(view, "#events", "created")
    assert Todos.counts().total == 0
  end

  test "toggle and delete update streams, stats, and activity", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    submit_task(view, "Toggle and delete me")
    [todo] = Todos.list_todos()

    view
    |> element("#toggle-todo-#{todo.id}")
    |> render_click()

    assert view |> element("#done-stat") |> render() =~ "1"
    assert has_element?(view, "#events", "toggled")

    view
    |> element("#delete-todo-#{todo.id}")
    |> render_click()

    refute has_element?(view, "#todos", "Toggle and delete me")
    assert view |> element("#total-stat") |> render() =~ "0"
    assert has_element?(view, "#events", "deleted")
  end

  test "broadcasts update another connected tab", %{conn: conn} do
    {:ok, first, _html} = live(conn, ~p"/")
    {:ok, second, _html} = live(build_conn(), ~p"/")

    submit_task(first, "Cross-tab task")

    assert has_element?(second, "#todos", "Cross-tab task")
    assert has_element?(second, "#events", "created")
  end

  test "presence counts connected views", %{conn: conn} do
    {:ok, first, _html} = live(conn, ~p"/")
    {:ok, second, _html} = live(build_conn(), ~p"/")

    assert render(first) =~ "2 viewing"
    assert render(second) =~ "2 viewing"
  end

  test "pulse messages render the heartbeat", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    send(view.pid, {:pulse, %{n: 1, at: DateTime.utc_now()}})

    assert render(view) =~ "pulse #1"
  end

  defp submit_task(view, body) do
    view
    |> form("#todo-form", todo: %{body: body})
    |> render_submit()
  end
end
