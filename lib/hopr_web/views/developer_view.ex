defmodule HoprWeb.DeveloperView do
  use HoprWeb, :view
  alias HoprWeb.DeveloperView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, DeveloperView, "user.json")}
  end

  def render("showUser.json", %{user: user}) do
    %{data: render_one(user, DeveloperView, "user.json")}
  end

  def render("showApplication.json", %{application: app}) do
    %{data: render_one(app, DeveloperView, "application.json")}
  end

  def render("showRoom.json", %{room: room}) do
    %{data: render_one(room, DeveloperView, "room.json")}
  end

  def render("user.json", %{developer: user}) do
    %{
      email: user.email,
      apiKey: user.apiKey,
      username: user.username,
      role: user.role,
    }
  end

  def render("application.json", %{developer: app}) do
    %{
      clientId: app.clientId,
      clientSecret: app.clientSecret,
      name: app.name, role: app.role,
    }
  end

  def render("room.json", %{developer: room}) do
    %{
      name: room.name,
      authKey: room.authKey,
    }
  end
end
