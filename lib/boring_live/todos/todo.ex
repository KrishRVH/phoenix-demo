defmodule BoringLive.Todos.Todo do
  @moduledoc "A single task. Body is trimmed and capped at 280 characters."
  use Ecto.Schema
  import Ecto.Changeset

  @max_body 280

  schema "todos" do
    field :body, :string
    field :done, :boolean, default: false
    timestamps()
  end

  @doc false
  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:body])
    |> update_change(:body, &trim_body/1)
    |> validate_required([:body])
    |> validate_length(:body, max: @max_body)
    |> check_constraint(:body,
      name: :body_length,
      message: "must be between 1 and 280 characters after trimming"
    )
  end

  @doc "Flips done without touching anything else."
  def toggle_changeset(todo), do: change(todo, done: not todo.done)

  def max_body, do: @max_body

  defp trim_body(body) when is_binary(body), do: String.trim(body)
  defp trim_body(body), do: body
end
