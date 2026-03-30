defmodule JamesWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :james

  plug CORSPlug, origin: ["http://localhost:5173"]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug JamesWeb.Router
end
