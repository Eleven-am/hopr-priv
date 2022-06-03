defmodule Hopr.Developer.Token do
  use Ecto.Schema
  import Ecto.Changeset
  alias Hopr.Developer.Application

  schema "tokens" do
    field :token, :string
    field :cypher, :string
    belongs_to :application, Application

    timestamps()
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token, :application_id, :cypher])
    |> validate_required([:token, :application_id, :cypher])
  end
end
