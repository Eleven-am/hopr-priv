defmodule Hopr.Repo.Migrations.CreateUser do
  use Ecto.Migration
  alias Hopr.Account.UserRole

  def change do
    UserRole.create_type()

    create table "users" do
      add :firstName, :string, null: false
      add :lastName, :string, null: false
      add :username, :string, null: false
      add :email, :string, null: false
      add :password, :string, null: false
      add :confirmedToken, :string, null: false
      add :confirmed, :boolean, default: false
      add :role, :user_role, null: false
      add :apiKey, :string, null: false

      timestamps()
    end

    create unique_index :users, [:username]
    create unique_index :users, [:email]
    create unique_index :users, [:apiKey]
  end
end
