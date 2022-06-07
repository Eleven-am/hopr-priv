defmodule HoprWeb.RoomChannel do
  use HoprWeb, :channel
  alias HoprWeb.UserTracker
  alias HoprWeb.Presence
  alias Hopr.Messaging

  def join(roomName, payload, socket) do
    case payload do
      %{"token" => auth_key, "username" => name} ->
        with {:ok, room} <- Messaging.get_room_by_auth_key(auth_key, socket.assigns.clientId, roomName) do
          UserTracker.track_api_connections(socket.transport_pid, socket.assigns.clientId)
          send(self(), :after_join)
          {:ok, assign(socket, name: name, reference: reference, room: room.name, roomId: room.id, scribe: true)}
        end

      %{"username" => name} ->
        UserTracker.track_api_connections(socket.transport_pid, socket.assigns.clientId)
        send(self(), :after_join)
        {:ok, assign(socket, name: name, reference: reference, scribe: false, room: roomName, roomId: nil)}

      _ ->
        {:error, "Invalid payload"}
    end
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.name, %{
        online_at: inspect(System.system_time(:second)),
        username: socket.assigns.name,
        reference: socket.assigns.reference,
        presenceState: "online"
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

  def handle_in("modPresenceState", %{"presenceState" => state}, socket) do
    Presence.update(socket, socket.assigns.name, %{
      online_at: inspect(System.system_time(:second)),
      username: socket.assigns.name,
      reference: socket.assigns.reference,
      presenceState: state
    })
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
