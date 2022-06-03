defmodule Hopr.Repo.Migrations.CreateApplication do
  use Ecto.Migration

  def change do
    create table "applications" do
      add :name, :string, null: false
      add :clientId, :string, null: false
      add :clientSecret, :string, null: false
      add :role, :user_role, null: false
      add :user_id, references "users"

      timestamps()
    end

    create unique_index :applications, [:clientId]
  end
end
