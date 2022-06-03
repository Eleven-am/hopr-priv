defmodule HoprWeb.RoomChannel do
  use HoprWeb, :channel
  alias HoprWeb.UserTracker
  alias HoprWeb.Presence
  alias Hopr.Encrypt

  def join(room, %{"username" => name}, socket) do
    reference = Encrypt.generateKey(1, 16)
    UserTracker.track_api_connections(socket.transport_pid, socket.assigns.clientId)
    HoprWeb.Endpoint.subscribe(reference)
    send(self(), :after_join)
    {:ok, assign(socket, name: name, reference: reference, room: room)}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.name, %{
        online_at: inspect(System.system_time(:second)),
        username: socket.assigns.name,
        reference: socket.assigns.reference,
        presenceState: "online"
      })

    push(socket, "presence_state", Presence.list(socket))
    push(socket, "inform", %{
      scribed: false,
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
    broadcast!(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("whisper", payload, socket) do
    case payload do
      %{"to" => reference, "message" => message} ->
        data = %{from: socket.assigns.reference, body: message, to: reference, username: socket.assigns.name}
        HoprWeb.Endpoint.broadcast_from!(self(), reference, "whisper", data)
    end
    {:noreply, socket}
  end
end
