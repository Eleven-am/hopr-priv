defmodule Hopr.Repo.Migrations.CreateMsgs do
  use Ecto.Migration

  def change do
    create table "messages" do
      add :payload, :map, default: %{}
      add :senderId, :string, null: false
      add :room_id, references "rooms"
      add :application_id, references "applications"

      timestamps()
    end
  end
end
