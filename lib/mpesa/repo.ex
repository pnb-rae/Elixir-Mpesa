defmodule Mpesa.Repo do
  use Ecto.Repo,
    otp_app: :mpesa,
    adapter: Ecto.Adapters.Postgres
end
