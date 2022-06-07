defmodule HoprWeb.UserSocket do
  use Phoenix.Socket
  alias HoprWeb.UserTracker
  alias Hopr.Developer.Application
  alias Hopr.Developer
  alias Hopr.Encrypt

  channel "*", HoprWeb.RoomChannel

  def connect(params, socket, _connect_info) do
    reference = Encrypt.generateKey(1, 16)
    case params do
      %{"token" => token} ->
        with {:ok, %Application{clientId: clientId, role: role}} <- Developer.authenticate_with_access_token(token) do
             with {:ok, count} <- UserTracker.count_api_channel(clientId, role) do
               {:ok, assign(socket, clientId: clientId, role: role, count: count, reference: reference)}
            end
        end
      %{"clientId" => clientId, "clientSecret" => secret} ->
        with {:ok, %Application{clientId: clientId, role: role}} <- Developer.authenticate_with_client_credentials(clientId, secret) do
             with {:ok, count} <- UserTracker.count_api_channel(clientId, role) do
               {:ok, assign(socket, clientId: clientId, role: role, count: count, reference: reference)}
            end
        end
     _ -> {:error, "Unable to authenticate"}
    end
  end

  def id(socket), do: "application:#{socket.assigns.clientId}"

end
