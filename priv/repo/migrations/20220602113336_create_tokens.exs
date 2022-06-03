defmodule Hopr.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table "tokens" do
      add :token, :string, null: false
      add :cypher, :string, null: false
      add :application_id, references "applications"

      timestamps()
    end

    create unique_index :tokens, [:token]
  end
end
