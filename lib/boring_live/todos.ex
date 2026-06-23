defmodule BoringLive.Todos do
  @moduledoc """
  The todo + activity context.

  Every mutation writes the row change and its audit event in one transaction,
  then fans the result out over `Phoenix.PubSub`. Subscribers —
  including the process that triggered the change — react in `handle_info/2`, so
  there is a single update path whether the change is local or remote. This is
  the part the SSE "re-render the whole world on every event" design was faking:
  here the broadcast carries exactly the changed row, and LiveView streams turn
  that into a minimal DOM diff.
  """
  import Ecto.Query, warn: false

  alias BoringLive.Repo
  alias BoringLive.Todos.{Event, Todo}

  @topic "todos"

  @doc "Subscribe the calling process to todo/activity/presence broadcasts."
  def subscribe, do: Phoenix.PubSub.subscribe(BoringLive.PubSub, @topic)

  def topic, do: @topic

  ## Reads

  def list_todos do
    Repo.all(from t in Todo, order_by: [desc: t.inserted_at, desc: t.id])
  end

  def recent_events(limit \\ 12) do
    Repo.all(from e in Event, order_by: [desc: e.inserted_at, desc: e.id], limit: ^limit)
  end

  @doc "Returns %{total: integer, done: integer} in a single query."
  def counts do
    Repo.one(
      from t in Todo,
        select: %{total: count(t.id), done: filter(count(t.id), t.done == true)}
    )
  end

  def change_todo(%Todo{} = todo \\ %Todo{}, attrs \\ %{}), do: Todo.changeset(todo, attrs)

  ## Writes

  def create_todo(attrs) do
    attrs
    |> create_transaction()
    |> case do
      {:ok, {todo, event}} ->
        _ = broadcast(:created, todo, event)
        {:ok, todo}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def toggle_todo(id) do
    with %Todo{} = todo <- Repo.get(Todo, id),
         {:ok, {todo, event}} <- toggle_transaction(todo) do
      _ = broadcast(:toggled, todo, event)
      {:ok, todo}
    else
      nil -> {:error, :not_found}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  def delete_todo(id) do
    with %Todo{} = todo <- Repo.get(Todo, id),
         {:ok, {todo, event}} <- delete_transaction(todo) do
      _ = broadcast(:deleted, todo, event)
      {:ok, todo}
    else
      nil -> {:error, :not_found}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  @showcase [
    "Ship the LiveView rewrite",
    "Delete the snapshot-fanout code path",
    "Wire Presence into the header",
    "Move the heartbeat into a GenServer",
    "Prove constraints at the database edge",
    "Write one honest integration test"
  ]

  @doc "Insert the standard demo tasks when they are absent."
  def seed_showcase do
    existing = Repo.all(from t in Todo, select: t.body) |> MapSet.new()

    Enum.each(@showcase, fn body ->
      if not MapSet.member?(existing, body) do
        _ = create_todo(%{"body" => body})
      end
    end)

    :ok
  end

  ## Internal

  defp create_transaction(attrs) do
    Repo.transaction(fn ->
      with {:ok, todo} <- Repo.insert(Todo.changeset(%Todo{}, attrs)),
           {:ok, event} <- insert_event("created", "Added #{quote_body(todo.body)}") do
        {todo, event}
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp toggle_transaction(todo) do
    Repo.transaction(fn ->
      with {:ok, todo} <- Repo.update(Todo.toggle_changeset(todo)),
           verb = if(todo.done, do: "Completed", else: "Reopened"),
           {:ok, event} <- insert_event("toggled", "#{verb} #{quote_body(todo.body)}") do
        {todo, event}
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp delete_transaction(todo) do
    Repo.transaction(fn ->
      with {:ok, todo} <- Repo.delete(todo),
           {:ok, event} <- insert_event("deleted", "Removed #{quote_body(todo.body)}") do
        {todo, event}
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_event(kind, summary) do
    Repo.insert(Event.changeset(%Event{}, %{kind: kind, summary: summary}))
  end

  defp broadcast(op, todo, event) do
    Phoenix.PubSub.broadcast(
      BoringLive.PubSub,
      @topic,
      {:mutation, %{op: op, todo: todo, event: event}}
    )
  end

  defp quote_body(body) do
    trimmed = if String.length(body) > 32, do: String.slice(body, 0, 32) <> "…", else: body
    "“" <> trimmed <> "”"
  end
end
