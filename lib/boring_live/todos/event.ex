defmodule BoringLive.Todos.Event do
  @moduledoc "An append-only audit record written in the same transaction as the mutation that caused it."
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(created toggled deleted)

  schema "events" do
    field :kind, :string
    field :summary, :string
    timestamps(updated_at: false)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:kind, :summary])
    |> validate_required([:kind, :summary])
    |> validate_inclusion(:kind, @kinds)
    |> check_constraint(:kind, name: :events_kind)
  end
end
