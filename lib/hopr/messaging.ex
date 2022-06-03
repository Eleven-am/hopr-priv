defmodule Hopr.Messaging do
  @moduledoc """
  The Hopr messaging system.

  This module provides the messaging system for Hopr.
  A scribed room is a room where messages are stored.
  The room is identified by a name and a unique auth key.
  Only the application that created the auth key can access the room.

  The room is a collection of messages.
  Each message is identified by a unique message id and includes payload(JSON) and meta data(Sender string).
  """

  import Ecto.Query, warn: false
  alias Hopr.Repo

  alias Hopr.Channel.Room
  alias Hopr.Message.Message
  alias Hopr.Developer.Application

  @doc """
  Gets a room by its auth key.
  auth_key: The auth key of the room.
  clientId: The client id of the developer.
  name: The name of the room.

  Returns the room if it exists.

  Raises an error if the room does not exist.
  ## Example

      iex> get_room_by_auth_key("auth_key", "clientId", "name")

      {:ok, room}
      {:error, error}

  """
  def get_room_by_auth_key(authKey, clientId, name) do
    case Repo.get_by(Room, authKey: authKey) do
      nil -> {:error, "Room not found"}
      room ->
        case Repo.get_by(Application, clientId: clientId) do
          nil -> {:error, "unknown client"}
          app ->
            if room.application_id == app.id do
              if room.name == name do
                {:ok, room}
              else
                {:error, "Room name does not match"}
              end
            else
              {:error, "You are not authorized to access this room"}
            end
        end
    end
  end

  @doc """
  Saves a message to the database.
  room_id is the id of the room to which the message belongs.
  sender the sender of the message
  payload the message to save

  ## Examples

      iex> save_message(1, "user1", "Hello World")
      %Message{}

  """
  def save_message(clientId, room_id, sender, payload) do
    case Repo.get(Room, room_id) do
      nil -> {:error, "Room not found"}
      room ->
        case Repo.get_by(Application, clientId: clientId) do
          nil -> {:error, "unknown client"}
          app ->
            if room.application_id == app.id do
              message = %{
                application_id: app.id,
                room_id: room_id,
                senderId: sender,
                payload: payload
              }

              %Message{}
              |> Message.changeset(message)
              |> Repo.insert()

              {:ok, message}
            else
              {:error, "You are not authorized to access this room"}
            end
        end
    end
  end

  @doc """
  Gets all the messages of a room.
  room_id is the id of the room to which the messages belongs.

  ## Examples

      iex> get_messages(1)
      %[%Message{}, ...]

  """
  def get_messages(room_id) do
    query = from m in Message, where: m.room_id == ^room_id
    Repo.all(query)
    |> Enum.map(fn x -> convert_to_map x end)
  end

  defp convert_to_map(schema) do
    %{
      content: schema.payload,
      sender: schema.sender,
    }
  end
end