defmodule Hopr.Developer do
  @moduledoc """
  The Developer module contains the developer-facing API.

  The developer API is used to interact with the Hopr node.
  Users should not need to use this API directly.
  """

  import Ecto.Query, warn: false
  alias Hopr.Repo

  alias Hopr.Account.User
  alias Hopr.Channel.Room
  alias Hopr.Developer.Application
  alias Hopr.Developer.Token
  alias Hopr.Encrypt

  @doc """
  Generates an application's access token.
  clientId is the application's clientId.
  clientSecret is the application's clientSecret.

  Raises an error if the application does not exist or the clientSecret is invalid or expired.

  ## Example

      iex>  generate_refresh_token(%{clientId: "0x1234567890123456789012345678901234567890", clientSecret: "0x1234567890123456789012345678901234567890"})
        {:ok, "0x1234567890123456789012345678901234567890"}
        {:error, reason}
  """
  def generate_refresh_token(id, secret) do
    with {:ok, app} <- getApplication(id, secret) do
      date = :os.system_time(:millisecond)
      thirty_six_hours = 3600 * 3600
      cypher = Encrypt.generateUUID()
      token = %{clientId: app.clientId, role: app.role, name: app.name}
      encrypt = Encrypt.encrypt(token)
      accessToken = Encrypt.encrypt(%{token: Encrypt.encrypt(token, cypher), cypher: cypher, expires: date + thirty_six_hours})
      saveToken(%{token: encrypt, application_id: app.id, cypher: cypher})
      {:ok, %{refreshToken: encrypt, expires: date + thirty_six_hours, accessToken: accessToken}}
    end
  end

  @doc """
  Generates an application's access token.
  refreshToken is the application's refreshToken.

  Raises an error if the application does not exist or the refreshToken is invalid or expired.

  ## Example

      iex>  generate_access_token(%{refreshToken: "0x1234567890123456789012345678901234567890"})
        {:ok, "0x1234567890123456789012345678901234567890"}
        {:error, reason}
  """
  def generate_access_token(token) do
    with {:ok, %{"clientId" => clientId}} <- Encrypt.decrypt(token) do
      case Repo.get_by(Token, token: token) do
        nil -> {:error, "Invalid refresh token."}
        newToken ->
          case Repo.get_by(Application, clientId: clientId) do
            nil -> {:error, "Invalid refresh token."}
            app ->
              if app.id == newToken.application_id do
                  date = :os.system_time(:millisecond)
                  object = %{clientId: app.clientId, role: app.role, name: app.name}
                  thirty_six_hours = 3600 * 3600
                  accessToken = Encrypt.encrypt(%{token: Encrypt.encrypt(object, newToken.cypher), cypher: newToken.cypher, expires: date + thirty_six_hours})
                  {:ok, %{refreshToken: token, expires: date + thirty_six_hours, accessToken: accessToken}}
              else
                {:error, "Invalid refresh token."}
              end
          end
      end
    end
  end

  @doc """
  Returns the application from the database using the accessToken provided.
  Raises an error if the accessToken is invalid or expired.
  Raises an error if the application does not exist.

  ## Example

      iex> authenticate_with_access_token("0x1234567890123456789012345678901234567890")
        {:ok, %{name, clientId, clientSecret, permissions}
        {:error, reason}
  """
  def authenticate_with_access_token(accessToken) do
    with {:ok, %{"token" => token, "cypher" => cypher, "expires" => date}} <- Encrypt.decrypt(accessToken) do
      if date < :os.system_time(:millisecond) do
        {:error, "Access token expired"}
      else
        with {:ok, %{"clientId" => clientId, "role" => role}} <- Encrypt.decrypt(token, cypher) do
          case Repo.get_by(Token, cypher: cypher) do
            nil -> {:error, "Invalid access token"}
            newToken ->
              case Repo.get_by(Application, clientId: clientId) do
                nil -> {:error, "Application not found"}
                app ->
                  if String.to_existing_atom(role) == app.role && newToken.application_id == app.id do
                    {:ok, app}
                  else
                    {:error, "Invalid access token"}
                  end
              end
          end
        end
      end
    end
  end

  @doc """
  Returns the application from the database using the clientId and clientSecret provided.
  Raises an error if the application does not exist.

  ## Example

      iex> authenticate_with_client_credentials("clientId", "clientSecret")
        {:ok, %{name, clientId, clientSecret, permissions}
        {:error, reason}
  """
  def authenticate_with_client_credentials(clientId, clientSecret) do
    case getApplication(clientId, clientSecret) do
      {:ok, app} ->
        {:ok, app}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a new room for the application.
  Raises an error if the application does not exist or if the application does not have the correct permissions.

  ## Example

      iex> create_room("clientId", "clientSecret", "roomName")
        {:ok, room}
        {:error, reason}
  """
  def create_room(clientId, clientSecret, roomName) do
    case Repo.get_by(Application, clientId: clientId) do
      nil -> {:error, "Application not found"}
      app ->
        if app.clientSecret == clientSecret do
          query = from m in Room, where: m.application_id == ^app.id
          roomSize = Repo.all(query)
                     |> length()

          if compareRoomSize?(app.role, roomSize) do
            authKey = Encrypt.generateUUID()
            room = %{name: roomName, application_id: app.id, authKey: authKey}

            %Room{}
            |> Room.changeset(room)
            |> Repo.insert()

            {:ok, room}
          else
            {:error, "The application has reached the maximum number of rooms"}
          end
        else
          {:error, "Invalid credentials"}
        end
    end
  end

  @doc """
  Generate a new application. using
  The name of the application to be created.
  The apiKey of the developer creating the application.
  The application permissions.

  ## Example

    iex> generate_application("my_app", "my_api_key", [:read, :write])
      {:ok, %{name, clientId, clientSecret, permissions}
      {:error, reason}
  """
  def create_application(name, apiKey, role \\ :HOBBYIST) do
    with {:ok, user} <- getUser(apiKey) do
      if compareRoles?(user.role, role) do
        data = %{apiKey: apiKey, role: role}
        clientSecret = Encrypt.encrypt(data)
        app = %{
          name: name, role: role,
          clientId: Encrypt.generateKey(1, 32),
          clientSecret: clientSecret,
          user_id: user.id
        }

        %Application{}
        |> Application.changeset(app)
        |> Repo.insert()
      else
        {:error, "User does not have the correct role."}
      end
    end
  end

  @doc """
  Creates a new user. Returns the user if successful.
  Raises an error if the user already exists or the password is invalid.
  """
  def create_user(user) do
    temp = %{
      "apiKey" => Encrypt.generateKey(1, 32),
      "confirmedToken" => Encrypt.generateKey(5, 16),
      "role" => "HOBBYIST",
      "confirmed" => false
    }

    newUser = Map.merge(temp, user)
    %User{}
    |> User.register(newUser)
    |> Repo.insert()
  end

  @doc """
  Returns the application from the database using the clientId and clientSecret provided.
  Raises an error if the application does not exist.
  """
  def getApplication(clientId, token) do
    with {:ok, %{"apiKey" => key, "role" => keyRole}} <- Encrypt.decrypt(token) do
      case Repo.get_by(Application, clientId: clientId) do
        nil -> {:error, "Application not found"}
        app ->
          with {:ok, user} <- getUser(key) do
            if String.to_existing_atom(keyRole) == app.role do
              if compareRoles?(user.role, app.role) do
                {:ok, app}
              else
                {:error, "User role does not match application role"}
              end
            else
              {:error, "Application role mismatch"}
            end
          end
      end
    end
  end

  @doc """
  Returns the user from the database using the apiKey provided.
  Raises an error if the user does not exist.
  """
  def getUser(apiKey) do
    case Repo.get_by(User, apiKey: apiKey) do
      nil -> {:error, "User not found"}
      user ->
        if user.confirmed do
          {:ok, user}
        else
          {:error, "User not confirmed"}
        end
    end
  end

  defp compareRoles?(role1, role2) do
    case role1 do
      :ADMIN -> true
      :PROFESSIONAL ->
      case role2 do
        :ADMIN -> false
        :PROFESSIONAL -> true
        :PERSONAL -> true
        :HOBBYIST -> true
        _ -> false
      end
      :PERSONAL ->
      case role2 do
        :ADMIN -> false
        :PROFESSIONAL -> false
        :PERSONAL -> true
        :HOBBYIST -> true
        _ -> false
      end
      :HOBBYIST ->
      case role2 do
        :ADMIN -> false
        :PROFESSIONAL -> false
        :PERSONAL -> false
        :HOBBYIST -> true
        _ -> false
      end
      _ -> false
    end
  end

  defp saveToken(token) do
    %Token{}
    |> Token.changeset(token)
    |> Repo.insert()
    |> IO.inspect()
  end

  defp compareRoomSize?(role, roomSize) do
    case role do
      :ADMIN -> true
      :PROFESSIONAL -> roomSize <= 100
      :PERSONAL -> roomSize <= 50
      :HOBBYIST -> false
    end
  end

end
