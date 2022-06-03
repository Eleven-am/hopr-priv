defmodule HoprWeb.ScribeChannel do
  use HoprWeb, :channel
  alias HoprWeb.UserTracker
  alias HoprWeb.Presence
  alias Hopr.Messaging
  alias Hopr.Encrypt

  def join("scribed:"<>roomName, payload, socket) do
    case payload do
      %{"token" => auth_key, "username" => name} ->
        with {:ok, room} <- Messaging.get_room_by_auth_key(auth_key, socket.assigns.clientId, roomName) do
          reference = Encrypt.generateKey(1, 16)
          UserTracker.track_api_connections(socket.transport_pid, socket.assigns.clientId)
          HoprWeb.Endpoint.subscribe(reference)
          send(self(), :after_join)
          {:ok, assign(socket, name: name, reference: reference, room: room.name, roomId: room.id)}
        end
      _ ->
        {:error, "No auth key provided"}
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

    messages = Messaging.get_messages(socket.assigns.roomId)
    push(socket, "presence_state", Presence.list(socket))
    push(socket, "messages", %{messages: messages})
    push(socket, "inform", %{
      scribed: true,
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
    Messaging.save_message(socket.assigns.clientId, socket.assigns.roomId, socket.assigns.name, payload)
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
    Messaging.save_message(socket.assigns.clientId, socket.assigns.roomId, socket.assigns.name, payload)
    broadcast!(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("whisper", payload, socket) do
    case payload do
      %{"to" => reference, "message" => message} ->
        data = %{from: socket.assigns.reference, body: message, to: reference, username: socket.assigns.name}
        Messaging.save_message(socket.assigns.clientId, socket.assigns.roomId, socket.assigns.name, payload)
        HoprWeb.Endpoint.broadcast_from!(self(), reference, "whisper", data)
    end
    {:noreply, socket}
  end
end
