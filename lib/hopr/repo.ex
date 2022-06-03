defmodule Hopr.Repo do
  use Ecto.Repo,
    otp_app: :hopr,
    adapter: Ecto.Adapters.Postgres
end
