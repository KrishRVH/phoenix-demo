defmodule BoringLiveWeb.Presence do
  @moduledoc """
  Tracks who is currently viewing the page. Presence is a CRDT replicated across
  the cluster over PubSub, so the viewer count is correct across nodes with no
  extra infrastructure — the kind of thing that is a project on most stacks and a
  one-liner here.
  """
  use Phoenix.Presence,
    otp_app: :boring_live,
    pubsub_server: BoringLive.PubSub
end
