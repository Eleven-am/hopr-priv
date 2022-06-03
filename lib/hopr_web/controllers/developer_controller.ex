defmodule HoprWeb.DeveloperController do
  use HoprWeb, :controller

  alias Hopr.Developer
  alias Hopr.Account.User

  action_fallback HoprWeb.FallbackController

  def index(conn, _params) do
    text(conn, "Hello Developer, the server is running!")
  end

  def createUser(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Developer.create_user(user_params) do
      conn
      |> put_status(:created)
      |> render("showUser.json", user: user)
    end
  end

  def createApplication(conn, %{"application" => %{"apiKey" => apiKey, "name" => name, "role" => role}}) do
    case Developer.create_application(name, apiKey, String.to_atom(role)) do
      {:error, msg} -> json(conn, %{error: msg})
      {:ok, application} ->
        conn
        |> put_status(:created)
        |> render("showApplication.json", application: application)
    end
  end

  def createRoom(conn, %{"room" => %{"clientId" => id, "clientSecret" => secret, "name" => name}}) do
    case Developer.create_room(id, secret, name) do
      {:error, msg} -> json(conn, %{error: msg})
      {:ok, room} ->
        conn
        |> put_status(:created)
        |> render("showRoom.json", room: room)
    end
  end

  def authRefresh(conn, %{"clientId" => id, "clientSecret" => secret}) do
    case Developer.generate_refresh_token(id, secret) do
      {:error, msg} -> json(conn, %{error: msg})
      {:ok, token} ->
        conn
        |> put_status(:created)
        |> json(token)
    end
  end

  def authAccess(conn, %{"refreshToken" => token}) do
    case Developer.generate_access_token(token) do
      {:error, msg} -> json(conn, %{error: msg})
      {:ok, token} ->
        conn
        |> put_status(:created)
        |> json(token)
    end
  end

end
