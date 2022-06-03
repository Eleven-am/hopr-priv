defmodule Hopr.Developer.Application do
    use Ecto.Schema
    import Ecto.Changeset
    alias Hopr.Account.UserRole

    schema "applications" do
        field :name, :string
        field :role, UserRole
        field :clientId, :string
        field :clientSecret, :string
        belongs_to :user, Hopr.Account.User
        has_many :rooms, Hopr.Channel.Room
        has_many :messages, Hopr.Message.Message
        has_many :tokens, Hopr.Developer.Token

        timestamps()
    end

    @doc false
    def changeset(app, attrs) do
        app
        |> cast(attrs, [:name, :role, :clientId, :clientSecret, :user_id])
        |> validate_required([:name, :role])
        |> unique_constraint(:name, message: "App name already taken")
    end
end