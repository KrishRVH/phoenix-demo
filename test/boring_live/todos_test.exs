defmodule BoringLive.TodosTest do
  use BoringLive.DataCase, async: true

  alias BoringLive.Todos

  test "counts start at zero" do
    assert Todos.counts() == %{total: 0, done: 0}
  end

  test "create_todo/1 trims the body, writes an event, and broadcasts the mutation" do
    Todos.subscribe()

    assert {:ok, todo} = Todos.create_todo(%{"body" => "  Write a focused test  "})
    assert todo.body == "Write a focused test"

    assert [%{kind: "created", summary: summary}] = Todos.recent_events()
    assert summary == "Added “Write a focused test”"

    todo_id = todo.id
    assert_receive {:mutation, %{op: :created, todo: %{id: ^todo_id}, event: %{kind: "created"}}}
  end

  test "create_todo/1 rejects blank, nil, and overlong bodies" do
    assert {:error, blank} = Todos.create_todo(%{"body" => "   "})
    assert %{body: ["can't be blank"]} = errors_on(blank)

    assert {:error, nil_body} = Todos.create_todo(%{"body" => nil})
    assert %{body: ["can't be blank"]} = errors_on(nil_body)

    assert {:error, too_long} = Todos.create_todo(%{"body" => String.duplicate("x", 281)})
    assert "should be at most 280 character(s)" in errors_on(too_long).body
  end

  test "toggle_todo/1 flips done, writes an event, updates counts, and broadcasts" do
    assert {:ok, todo} = Todos.create_todo(%{"body" => "Toggle me"})
    Todos.subscribe()

    assert {:ok, toggled} = Todos.toggle_todo(todo.id)
    assert toggled.done
    assert Todos.counts() == %{total: 1, done: 1}

    todo_id = todo.id

    assert_receive {:mutation,
                    %{op: :toggled, todo: %{id: ^todo_id, done: true}, event: %{kind: "toggled"}}}
  end

  test "delete_todo/1 deletes the row, writes an event, and broadcasts" do
    assert {:ok, todo} = Todos.create_todo(%{"body" => "Delete me"})
    Todos.subscribe()

    assert {:ok, deleted} = Todos.delete_todo(todo.id)
    assert deleted.id == todo.id
    assert Todos.counts() == %{total: 0, done: 0}

    todo_id = todo.id
    assert_receive {:mutation, %{op: :deleted, todo: %{id: ^todo_id}, event: %{kind: "deleted"}}}
  end

  test "toggle_todo/1 and delete_todo/1 tolerate stale ids" do
    assert {:error, :not_found} = Todos.toggle_todo(-1)
    assert {:error, :not_found} = Todos.delete_todo(-1)
  end

  test "seed_showcase/0 fills missing demo tasks once in a sequential run" do
    assert :ok = Todos.seed_showcase()
    assert Todos.counts().total == 6

    assert :ok = Todos.seed_showcase()
    assert Todos.counts().total == 6
  end
end
