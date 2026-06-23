defmodule BoringLiveWeb.TodoLive do
  @moduledoc """
  The whole app: a todo list, an append-only activity feed, live stats, a live
  viewer count, and a server heartbeat — in one LiveView, holding its UI state on
  the server and shipping diffs over a single socket.

  Mutations never touch the DOM directly. They call the context, which writes and
  broadcasts; the broadcast comes back through `handle_info/2` (to every tab,
  including this one) and updates a stream. One path, local or remote.
  """
  use BoringLiveWeb, :live_view

  alias BoringLive.Todos
  alias BoringLiveWeb.Presence

  @impl true
  def mount(_params, _session, socket) do
    _ =
      if connected?(socket) do
        _ = Todos.subscribe()

        _ =
          Presence.track(self(), Todos.topic(), socket.id, %{
            online_at: System.system_time(:second)
          })
      end

    c = Todos.counts()

    {:ok,
     socket
     |> assign(
       page_title: "Todo + activity",
       total: c.total,
       done: c.done,
       char_count: 0,
       pulse: nil,
       viewers: viewer_count()
     )
     |> assign_form(Todos.change_todo())
     |> stream(:todos, Todos.list_todos())
     |> stream(:events, Todos.recent_events(), limit: 12)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold text-zinc-900">Boring LiveView</h1>
          <p class="mt-1 text-sm text-zinc-500">
            Open this in two tabs; tasks, activity, viewer count, and pulse update live.
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <span class="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-700">
            <span class="relative flex h-2 w-2">
              <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span class="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
            </span>
            {@viewers} viewing
          </span>
          <span
            class="rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-600"
            title="Server heartbeat from a GenServer, pushed over PubSub"
          >
            pulse {pulse_label(@pulse)}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <.stat id="total-stat" label="Total" value={@total} tone="text-zinc-900" />
        <.stat id="done-stat" label="Done" value={@done} tone="text-emerald-600" />
        <.stat id="active-stat" label="Active" value={@total - @done} tone="text-amber-600" />
      </div>

      <.form id="todo-form" for={@form} phx-change="validate" phx-submit="save" class="space-y-1">
        <div class="items-end gap-3 sm:flex">
          <div class="flex-1">
            <.input
              field={@form[:body]}
              type="textarea"
              label="New task"
              rows="2"
              maxlength="280"
              phx-debounce="120"
              placeholder="What needs doing?"
            />
          </div>
          <.button phx-disable-with="Adding…" class="mt-3 w-full sm:mb-[2px] sm:w-auto">Add task</.button>
        </div>
        <p class="text-right text-xs text-zinc-400">{@char_count}/280</p>
      </.form>

      <div class="grid gap-6 lg:grid-cols-5">
        <div class="space-y-3 lg:col-span-3">
          <h2 class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Tasks</h2>

          <div
            :if={@total == 0}
            class="rounded-xl border border-dashed border-zinc-300 p-8 text-center text-sm text-zinc-400"
          >
            Nothing here yet. Add a task, or <button
              phx-click="seed"
              class="font-medium text-zinc-700 underline"
            >load the showcase</button>.
          </div>

          <div id="todos" phx-update="stream" class="space-y-2">
            <div
              :for={{dom_id, todo} <- @streams.todos}
              id={dom_id}
              class="group flex items-center gap-3 rounded-xl border border-zinc-200 bg-white px-4 py-3"
            >
              <button
                phx-click="toggle"
                phx-value-id={todo.id}
                id={"toggle-todo-#{todo.id}"}
                aria-pressed={todo.done}
                aria-label={toggle_label(todo)}
                class={[
                  "flex h-5 w-5 shrink-0 items-center justify-center rounded-md border transition",
                  (todo.done && "border-emerald-500 bg-emerald-500 text-white") ||
                    "border-zinc-300 hover:border-zinc-400"
                ]}
              >
                <.icon :if={todo.done} name="hero-check-mini" class="h-3.5 w-3.5" />
              </button>

              <span class={[
                "min-w-0 flex-1 break-words text-sm",
                (todo.done && "text-zinc-400 line-through") || "text-zinc-800"
              ]}>
                {todo.body}
              </span>

              <button
                phx-click="delete"
                phx-value-id={todo.id}
                id={"delete-todo-#{todo.id}"}
                data-confirm="Delete this task?"
                aria-label={"Delete #{todo.body}"}
                class="text-zinc-300 opacity-100 transition hover:text-red-500 focus:text-red-500 sm:opacity-0 sm:group-hover:opacity-100 sm:group-focus-within:opacity-100"
              >
                <.icon name="hero-trash-mini" class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        <div class="space-y-3 lg:col-span-2">
          <h2 class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Activity</h2>
          <div
            id="events"
            phx-update="stream"
            aria-live="polite"
            aria-relevant="additions text"
            class="space-y-1.5"
          >
            <div
              :for={{dom_id, ev} <- @streams.events}
              id={dom_id}
              class="flex items-baseline gap-2 text-xs"
            >
              <span class={["rounded px-1.5 py-0.5 font-medium", kind_class(ev.kind)]}>{ev.kind}</span>
              <span class="flex-1 text-zinc-600">{ev.summary}</span>
              <time
                datetime={datetime_attr(ev.inserted_at)}
                class="shrink-0 tabular-nums text-zinc-400"
              >
                {format_time(ev.inserted_at)}
              </time>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :tone, :string, required: true

  defp stat(assigns) do
    ~H"""
    <div id={@id} class="rounded-xl border border-zinc-200 bg-white p-4">
      <div class={["text-2xl font-semibold", @tone]}>{@value}</div>
      <div class="text-xs uppercase tracking-wide text-zinc-500">{@label}</div>
    </div>
    """
  end

  ## Events from this tab

  @impl true
  def handle_event("validate", %{"todo" => params}, socket) do
    changeset = %{Todos.change_todo(%BoringLive.Todos.Todo{}, params) | action: :validate}
    body = Map.get(params, "body", "")
    {:noreply, socket |> assign(:char_count, String.length(body)) |> assign_form(changeset)}
  end

  def handle_event("save", %{"todo" => params}, socket) do
    case Todos.create_todo(params) do
      {:ok, _todo} ->
        {:noreply, socket |> assign(:char_count, 0) |> assign_form(Todos.change_todo())}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, %{changeset | action: :validate})}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    _result = Todos.toggle_todo(id)
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    _result = Todos.delete_todo(id)
    {:noreply, socket}
  end

  def handle_event("seed", _params, socket) do
    Todos.seed_showcase()
    {:noreply, socket}
  end

  ## Broadcasts (from any tab, including this one)

  @impl true
  def handle_info({:mutation, %{op: op, todo: todo, event: event}}, socket) do
    socket =
      case op do
        :created ->
          socket |> stream_insert(:todos, todo, at: 0) |> update(:total, &(&1 + 1))

        :toggled ->
          socket
          |> stream_insert(:todos, todo)
          |> update(:done, &(&1 + if(todo.done, do: 1, else: -1)))

        :deleted ->
          socket
          |> stream_delete(:todos, todo)
          |> update(:total, &(&1 - 1))
          |> update(:done, &(&1 - if(todo.done, do: 1, else: 0)))
      end

    {:noreply, stream_insert(socket, :events, event, at: 0, limit: 12)}
  end

  def handle_info({:pulse, pulse}, socket) do
    {:noreply, assign(socket, :pulse, pulse)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :viewers, viewer_count())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  ## Helpers

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp viewer_count, do: Presence.list(Todos.topic()) |> map_size()

  defp pulse_label(nil), do: "waiting"
  defp pulse_label(%{n: n}), do: "##{n}"

  defp toggle_label(%{done: true, body: body}), do: "Mark #{body} active"
  defp toggle_label(%{body: body}), do: "Mark #{body} done"

  defp kind_class("created"), do: "bg-emerald-100 text-emerald-700"
  defp kind_class("toggled"), do: "bg-sky-100 text-sky-700"
  defp kind_class("deleted"), do: "bg-red-100 text-red-700"
  defp kind_class(_), do: "bg-zinc-100 text-zinc-600"

  defp datetime_attr(%NaiveDateTime{} = at),
    do: at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()

  defp datetime_attr(%DateTime{} = at), do: DateTime.to_iso8601(at)

  defp format_time(%NaiveDateTime{} = at), do: Calendar.strftime(at, "%H:%M:%S")
  defp format_time(%DateTime{} = at), do: Calendar.strftime(at, "%H:%M:%S")
end
