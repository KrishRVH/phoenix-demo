defmodule BoringLive.Repo.Migrations.CreateTodos do
  use Ecto.Migration

  def change do
    create table(:todos) do
      add :body, :text, null: false
      add :done, :boolean, null: false, default: false

      timestamps()
    end

    # Same rule the changeset enforces, enforced again where it actually lives.
    # Cheap insurance against a bad migration, a raw SQL write, or a future caller
    # that forgets the changeset.
    create constraint(:todos, :body_length, check: "char_length(btrim(body)) between 1 and 280")
  end
end
