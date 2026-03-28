defmodule JamesWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :james

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug JamesWeb.Router
end
