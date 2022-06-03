defmodule Hopr.Repo.Migrations.CreateRoom do
  use Ecto.Migration

  def change do
    create table "rooms" do
      add :name, :string
      add :authKey, :string
      add :application_id, references "applications"

      timestamps()
    end

    create unique_index :rooms, [:authKey]
  end
end
