defmodule HoprWeb.RoomChannel do
  use HoprWeb, :channel
  alias HoprWeb.UserTracker
  alias HoprWeb.Presence
  alias Hopr.Messaging

  def join(roomName, payload, socket) do
    roomId = nil
    auth_key = Map.get(payload, "token")
    name = Map.get(payload, "username")
    id = Map.get(payload, "identifier")
    post_address = Map.get(payload, "post_address")

    if (name == nil || id == nil) do
      {:error, "Invalid payload"}

    else
      if (auth_key != nil) do
        with {:ok, room} <- Messaging.get_room_by_auth_key(auth_key, socket.assigns.clientId, roomName) do
          ^roomId = room.name
        end
      end

      scribe = roomId != nil
      UserTracker.track_api_connections(socket.transport_pid, socket.assigns.clientId)
      send(self(), :after_join)

      HoprWeb.Endpoint.unsubscribe(socket.assigns.reference)
      HoprWeb.Endpoint.subscribe(socket.assigns.reference)
      {:ok, assign(socket, name: name, scribe: scribe, room: roomName, roomId: roomId, identifier: id, post_address: post_address)}
    end
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.identifier, %{
        online_at: inspect(System.system_time(:second)),
        username: socket.assigns.name,
        reference: socket.assigns.reference,
        identifier: socket.assigns.identifier,
        presenceState: "online", metadata: %{}
      })

    if (socket.assigns.roomId != nil && socket.assigns.scribe) do
      messages = Messaging.get_messages(socket.assigns.roomId)
      push(socket, "messages", %{messages: messages})
    end

    push(socket, "presence_state", Presence.list(socket))
    push(socket, "inform", %{
      scribed: socket.assigns.scribe,
      room: socket.assigns.room,
      username: socket.assigns.name,
      reference: socket.assigns.reference
    })

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: _, event: _event, payload: payload}, socket) do
    push(socket, "whisper", payload)
    {:noreply, socket}
  end

  def handle_in("speak", payload, socket) do
    if (socket.assigns.roomId != nil && socket.assigns.scribe) do
      Messaging.save_message(socket.assigns.clientId, socket.assigns.roomId, socket.assigns.name, payload)
    end

    broadcast_from!(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("modPresenceState", payload, socket) do
    case payload do
      %{"presenceState" => state, "metadata" => data} ->
        Presence.update(socket, socket.assigns.identifier, %{
          online_at: inspect(System.system_time(:second)),
          username: socket.assigns.name,
          reference: socket.assigns.reference,
          identifier: socket.assigns.identifier,
          presenceState: state, metadata: data
        })

      %{"presenceState" => state} ->
        Presence.update(socket, socket.assigns.identifier, %{
          online_at: inspect(System.system_time(:second)),
          username: socket.assigns.name,
          reference: socket.assigns.reference,
          identifier: socket.assigns.identifier,
          presenceState: state, metadata: %{}
        })

    end
    {:noreply, socket}
  end

  def handle_in("shout", payload, socket) do
    if (socket.assigns.roomId != nil && socket.assigns.scribe) do
      Messaging.save_message(socket.assigns.clientId, socket.assigns.roomId, socket.assigns.name, payload)
    end

    broadcast!(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("whisper", payload, socket) do
    case payload do
      %{"to" => reference, "message" => message} ->
        data = %{from: socket.assigns.reference, body: message, to: reference, username: socket.assigns.name}

        if (socket.assigns.roomId != nil && socket.assigns.scribe) do
          Messaging.save_message(socket.assigns.clientId, socket.assigns.roomId, socket.assigns.name, payload)
        end

        HoprWeb.Endpoint.broadcast_from!(self(), reference, "whisper", data)
      _ ->
        push(socket, "response", %{error: "Couldn't find a reference to send the message to"})
    end
    {:noreply, socket}
  end
end
