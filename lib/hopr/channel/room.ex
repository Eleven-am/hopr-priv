defmodule Hopr.Channel.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :authKey, :string
    has_many :messages, Hopr.Message.Message
    belongs_to :application, Hopr.Developer.Application

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :authKey, :application_id])
    |> validate_required([:name, :authKey, :application_id])
  end
end
