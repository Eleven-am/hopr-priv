defmodule Hopr.Message.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :payload, :map, default: %{}
    field :senderId, :string
    belongs_to :room, Hopr.Channel.Room
    belongs_to :application, Hopr.Developer.Application

  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender, :payload, :room_id, :application_id])
    |> validate_required([:sender, :content, :room_id, :application_id])
  end
end
