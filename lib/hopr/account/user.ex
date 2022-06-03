defmodule Hopr.Account.UserRole do
  use EctoEnum, type: :user_role, enums: [:ADMIN, :HOBBYIST, :PERSONAL, :PROFESSIONAL]
end

defmodule Hopr.Account.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Hopr.Account.UserRole

  @mail_regex ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/

  schema "users" do
    field :apiKey, :string, redact: true
    field :confirmedToken, :string
    field :email, :string
    field :firstName, :string
    field :lastName, :string
    field :password, :string, redact: true
    field :username, :string
    field :confirmed, :boolean, default: false
    field :role, UserRole

    timestamps()
  end

  @doc false
  def register(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role, :username, :confirmed, :confirmedToken, :apiKey, :firstName, :lastName])
    |> validate_required([:username, :email, :password, :firstName, :lastName])
    |> unique_constraint(:username, message: "Username already taken")
    |> unique_constraint(:email, message: "An account with this email already exists")
    |> unique_constraint(:user_id)
    |> validate_format(:email, @mail_regex, message: "Invalid email format provided")
    |> validate_format(:password, ~r/[0-9]+/, message: "Password must contain a number") # has a number
    |> validate_format(:password, ~r/[A-Z]+/, message: "Password must contain an upper-case letter") # has an upper case letter
    |> validate_format(:password, ~r/[a-z]+/, message: "Password must contain a lower-case letter") # has a lower case letter
    |> validate_format(:password, ~r/[#\!\-\?&@\$%^&*\(\)]+/, message: "Password must contain a symbol") # Has a symbol
    |> validate_confirmation(:password)
    |> encrypt_password()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role, :username, :confirmed, :confirmedToken, :apiKey, :firstName, :lastName])
    |> validate_required([:username, :email, :password, :firstName, :lastName])
  end

  defp encrypt_password(user) do
    case fetch_field!(user, :password) do
      nil -> user
      password ->
        IO.inspect(password)
        encrypted_password = Bcrypt.Base.hash_password(password, Bcrypt.Base.gen_salt(12, true))
        put_change(user, :password, encrypted_password)
    end
  end
end