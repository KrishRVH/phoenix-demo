defmodule BoringLive.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :kind, :string, null: false
      add :summary, :string, null: false

      timestamps(updated_at: false)
    end

    create constraint(:events, :events_kind, check: "kind in ('created', 'toggled', 'deleted')")
    create index(:events, [:inserted_at])
  end
end
