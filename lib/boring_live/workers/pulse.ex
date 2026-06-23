defmodule BoringLive.Workers.Pulse do
  @moduledoc """
  A trivial supervised process that broadcasts a heartbeat every few seconds.

  It exists to make one point concrete: on the BEAM, "a thing that runs on a
  schedule and pushes to clients" is a dozen lines and zero dependencies — no
  cron, no queue, no separate worker tier. For durable, retryable jobs you would
  reach for Oban (also just Postgres), but periodic in-memory work is this.
  """
  use GenServer

  @interval :timer.seconds(5)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, 0, name: __MODULE__)

  @impl true
  def init(count) do
    schedule()
    {:ok, count}
  end

  @impl true
  def handle_info(:tick, count) do
    count = count + 1

    _ =
      Phoenix.PubSub.broadcast(
        BoringLive.PubSub,
        BoringLive.Todos.topic(),
        {:pulse, %{n: count, at: DateTime.utc_now()}}
      )

    schedule()
    {:noreply, count}
  end

  defp schedule, do: Process.send_after(self(), :tick, @interval)
end
