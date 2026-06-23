# Boring LiveView

A compact Phoenix LiveView demo: a todo list with append-only activity, live
stats, a viewer count, and a server heartbeat.

The point of the app is the runtime model. UI state lives on the server, every
open tab receives the same PubSub mutation, and LiveView streams turn those
changes into small DOM diffs. There is no separate websocket gateway, realtime
broker, cache, queue, or npm build chain.

## Stack

- Elixir 1.20 / OTP 29, pinned by mise
- Phoenix 1.7 + LiveView 1.0
- Ecto + PostgreSQL
- Phoenix.PubSub and Phoenix.Presence
- A supervised GenServer heartbeat
- Bandit, Tailwind, and esbuild

## Run It

Prerequisites: `mise` and a local PostgreSQL server. Development database
credentials are in `config/dev.exs` (`postgres` / `postgres`).

```sh
mise run install
mise run setup
mise run dev
```

Then open http://localhost:4000 in two browser tabs. Add, complete, and delete a
task in one tab; the other tab updates immediately, the viewer count shows both
tabs, and the pulse ticks every five seconds.

## Quality Gate

```sh
mise run fmt
mise run fmt:check
mise run lint
mise run test
mise run check
mise run ci
```

`mise run check` is the normal local gate. `mise run ci` adds dependency audits,
docs, coverage, and Sobelow.

## What To Read

- `lib/boring_live/todos.ex`: the context. Mutations write the row and audit
  event in one transaction, then broadcast the specific change.
- `lib/boring_live_web/live/todo_live.ex`: the LiveView. Events call the context;
  broadcasts update streams and counters.
- `lib/boring_live_web/presence.ex`: viewer tracking over PubSub.
- `lib/boring_live/workers/pulse.ex`: scheduled work as a supervised process.
- `priv/repo/migrations`: database constraints that mirror changeset rules.
