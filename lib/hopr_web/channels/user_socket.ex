defmodule HoprWeb.UserSocket do
  use Phoenix.Socket
  alias HoprWeb.UserTracker
  alias Hopr.Developer.Application
  alias Hopr.Developer

  channel "scribed:*", HoprWeb.ScribeChannel
  channel "open:*", HoprWeb.RoomChannel

  def connect(params, socket, _connect_info) do
    case params do
      %{"token" => token} ->
        with {:ok, %Application{clientId: clientId, role: role}} <- Developer.authenticate_with_access_token(token) do
             with {:ok, count} <- UserTracker.count_api_channel(clientId, role) do
                {:ok, assign(socket, clientId: clientId, role: role, count: count)}
            end
        end
      %{"clientId" => clientId, "clientSecret" => secret} ->
        with {:ok, %Application{clientId: clientId, role: role}} <- Developer.authenticate_with_client_credentials(clientId, secret) do
             with {:ok, count} <- UserTracker.count_api_channel(clientId, role) do
                {:ok, assign(socket, clientId: clientId, role: role, count: count)}
            end
        end
     _ -> {:error, "Unable to authenticate"}
    end
  end

  def id(socket), do: "application:#{socket.assigns.clientId}"

end
